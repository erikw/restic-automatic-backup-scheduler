#!/usr/bin/env bash
# Make a backup with restic to Backblaze B2.
#
# This script is typically run (as root user) either like:
# - from restic service/timer: $PREFIX/etc/systemd/system/restic-backup.{service,timer}
# - from a cronjob: $PREFIX/etc/cron.d/restic
# - manually by a user. For it to work, the environment variables must be set in the shell where this script is executed
#   $ source $PREFIX/etc/default.env.sh
#   $ restic_backup.sh

set -o errexit
set -o pipefail
[[ "${TRACE-0}" =~ ^1|t|y|true|yes$ ]] && set -o xtrace

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock
}
trap exit_hook INT TERM


# Assert that all needed environment variables are set.
# TODO in future if this grows, move this to a restic_lib.sh
assert_envvars() {
	local varnames=("$@")
	for varname in "${varnames[@]}"; do
		if [ -z ${!varname+x} ]; then
			printf "%s must be set for this script to work.\n\nDid you forget to source a {{ INSTALL_PREFIX }}/etc/restic/*.env.sh profile in the current shell before executing this script?\n" "$varname" >&2
			exit 1
		fi
	done
}

warn_on_missing_envvars() {
	local unset_envs=()
	local varnames=("$@")
	for varname in "${varnames[@]}"; do
		if [ -z "${!varname-}" ]; then
			unset_envs=("${unset_envs[@]}" "$varname")
		fi
	done

	if [ ${#unset_envs[@]} -gt 0 ]; then
		printf "The following env variables are recommended, but have not been set. This script may not work as expected: %s\n" "${unset_envs[*]}" >&2
	fi
}

# Log the backup summary stats to a CSV file
logBackupStatsCsv() {
	local snapId="$1" added="$2" removed="$3" snapSize="$4"
	local logFile
	logFile="${RESTIC_BACKUP_STATS_DIR}/$(date '+%Y')-stats.log.csv"
	test -e "$logFile" || install -D -m 0644 <(echo "Date, Snapshot ID, Added, Removed, Snapshot size") "$logFile"
	# DEV-NOTE: using `ex` due `sed` inconsistencies (GNU vs. BSD) and `awk` cannot edit in-place. `ex` does a good job
	printf '1a\n%s\n.\nwq\n' "$(date '+%F %H:%M:%S'), ${snapId}, ${added}, ${removed}, ${snapSize}" | ex "$logFile"
}

# Notify the backup summary stats to the user
notifyBackupStats() {
	local statsMsg="$1"
	if [ -w "$RESTIC_BACKUP_NOTIFICATION_FILE" ]; then
		echo "$statsMsg" >> "$RESTIC_BACKUP_NOTIFICATION_FILE"
	else
		echo "[WARN] Couldn't write to the backup notification file. File not found or not writable: ${RESTIC_BACKUP_NOTIFICATION_FILE}"
	fi
}

# ------------
# === Main ===
# ------------

assert_envvars \
	RESTIC_BACKUP_PATHS RESTIC_BACKUP_TAG \
	RESTIC_BACKUP_EXCLUDE_FILE RESTIC_BACKUP_EXTRA_ARGS RESTIC_REPOSITORY RESTIC_VERBOSITY_LEVEL \
	RESTIC_RETENTION_HOURS RESTIC_RETENTION_DAYS RESTIC_RETENTION_MONTHS RESTIC_RETENTION_WEEKS RESTIC_RETENTION_YEARS

warn_on_missing_envvars \
	B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_CONNECTIONS \
	RESTIC_PASSWORD_FILE

# Convert to arrays, as arrays should be used to build command lines. See https://github.com/koalaman/shellcheck/wiki/SC2086
IFS=':' read -ra backup_paths <<< "$RESTIC_BACKUP_PATHS"

# Convert to array, an preserve spaces. See #111
backup_extra_args=( )
if [ -n "$RESTIC_BACKUP_EXTRA_ARGS" ]; then
	while IFS= read -r -d ''; do
	backup_extra_args+=( "$REPLY" )
	done < <(xargs printf '%s\0' <<<"$RESTIC_BACKUP_EXTRA_ARGS")
fi

B2_ARG=
[ -z "${B2_CONNECTIONS+x}" ] || B2_ARG=(--option b2.connections="$B2_CONNECTIONS")

# If you need to run some commands before performing the backup; create this file, put them there and make the file executable.
PRE_SCRIPT="{{ INSTALL_PREFIX }}/etc/restic/pre_backup.sh"
test -x "$PRE_SCRIPT" && "$PRE_SCRIPT"

# Set up exclude files: global + path-specific ones
# NOTE that restic will fail the backup if not all listed --exclude-files exist. Thus we should only list them if they are really all available.
##  Global backup configuration.
exclusion_args=(--exclude-file "$RESTIC_BACKUP_EXCLUDE_FILE")
## Self-contained backup exclusion files per backup path. E.g. having an USB disk at /mnt/media in RESTIC_BACKUP_PATHS,
# then a file /mnt/media/.backup_exclude.txt will automatically be detected and used:
for backup_path in "${backup_paths[@]}"; do
	if [ -f "$backup_path/.backup_exclude.txt" ]; then
		exclusion_args=("${exclusion_args[@]}" --exclude-file "$backup_path/.backup_exclude.txt")
	fi
done

# --one-file-system is not supportd on Windows (=msys).
FS_ARG=
test "$OSTYPE" = msys || FS_ARG=--one-file-system

# NOTE start all commands in background and wait for them to finish.
# Reason: bash ignores any signals while child process is executing and thus the trap exit hook is not triggered.
# However if put in subprocesses, wait(1) waits until the process finishes OR signal is received.
# Reference: https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash

# Remove locks from other stale processes to keep the automated backup running.
restic unlock &
wait $!

# Do the backup!
# See restic-backup(1) or http://restic.readthedocs.io/en/latest/040_backup.html
# --one-file-system makes sure we only backup exactly those mounted file systems specified in $RESTIC_BACKUP_PATHS, and thus not directories like /dev, /sys etc.
# --tag lets us reference these backups later when doing restic-forget.
restic backup \
	--verbose="$RESTIC_VERBOSITY_LEVEL" \
	$FS_ARG \
	--tag "$RESTIC_BACKUP_TAG" \
	"${B2_ARG[@]}" \
	"${exclusion_args[@]}" \
	"${backup_extra_args[@]}" \
	"${backup_paths[@]}" &
wait $!

# Dereference and delete/prune old backups.
# See restic-forget(1) or http://restic.readthedocs.io/en/latest/060_forget.html
# --group-by only the tag and path, and not by hostname. This is because I create a B2 Bucket per host, and if this hostname accidentially change some time, there would now be multiple backup sets.
restic forget \
	--verbose="$RESTIC_VERBOSITY_LEVEL" \
	--tag "$RESTIC_BACKUP_TAG" \
	"${B2_ARG[@]}" \
	--prune \
	--group-by "paths,tags" \
	--keep-hourly "$RESTIC_RETENTION_HOURS" \
	--keep-daily "$RESTIC_RETENTION_DAYS" \
	--keep-weekly "$RESTIC_RETENTION_WEEKS" \
	--keep-monthly "$RESTIC_RETENTION_MONTHS" \
	--keep-yearly "$RESTIC_RETENTION_YEARS" &
wait $!

# Check repository for errors.
# NOTE this takes much time (and data transfer from remote repo?), do this in a separate systemd.timer which is run less often.
#restic check &
#wait $!

echo "Backup & cleaning is done."

# (optional) Compute backup summary stats
if [[ -n "$RESTIC_BACKUP_STATS_DIR" || -n "$RESTIC_BACKUP_NOTIFICATION_FILE" ]]; then
	echo 'Silently computing backup summary stats...'
	latest_snapshots=$(restic snapshots --tag "$RESTIC_BACKUP_TAG" --latest 2 --compact \
		| grep -Ei "^[abcdef0-9]{8} " \
		| awk '{print $1}' \
		| tail -2 \
		| tr '\n' ' ')
	latest_snapshot_diff=$(echo "$latest_snapshots"	| xargs restic diff)
	added=$(echo "$latest_snapshot_diff" | grep -i 'added:' | awk '{print $2 " " $3}')
	removed=$(echo "$latest_snapshot_diff" | grep -i 'removed:' | awk '{print $2 " " $3}')
	snapshot_size=$(restic stats latest --tag "$RESTIC_BACKUP_TAG" | grep -i 'total size:' | cut -d ':' -f2 | xargs)  # xargs acts as trim
	snapshotId=$(echo "$latest_snapshots" | cut -d ' ' -f2)
	statsMsg="Added: ${added}. Removed: ${removed}. Snap size: ${snapshot_size}"

	echo "$statsMsg"
	test -n "$RESTIC_BACKUP_STATS_DIR"         && logBackupStatsCsv "$snapshotId" "$added" "$removed" "$snapshot_size"
	test -n "$RESTIC_BACKUP_NOTIFICATION_FILE" && notifyBackupStats "$statsMsg"
fi
