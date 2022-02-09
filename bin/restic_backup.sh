#!/usr/bin/env bash
# Make a backup with restic to Backblaze B2.
#
# This script is typically run (as root user) either like:
# - from restic service/timer: $PREFIX/etc/systemd/system/restic-backup.{service,timer}
# - from a cronjob: $PREFIX/etc/cron.d/restic
# - manually by a user. For it to work, the environment variables must be set in the shell where this script is executed
#   $ source $PREFIX/etc/default.env.sh
#   $ restic_backup.sh

# Exit on error, unset var, pipe failure
set -euo pipefail

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
			printf "%s must be set for this script to work.\n\nDid you forget to source a /etc/restic/*.env.sh profile in the current shell before executing this script?\n" "$varname" >&2
			exit 1
		fi
	done
}
assert_envvars \
	B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_CONNECTIONS \
	RESTIC_BACKUP_PATHS RESTIC_BACKUP_TAG \
	RESTIC_BACKUP_EXCLUDE_FILE RESTIC_BACKUP_EXTRA_ARGS RESTIC_PASSWORD_FILE RESTIC_REPOSITORY RESTIC_VERBOSITY_LEVEL \
	RESTIC_RETENTION_DAYS RESTIC_RETENTION_MONTHS RESTIC_RETENTION_WEEKS RESTIC_RETENTION_YEARS


# Convert to arrays, as arrays should be used to build command lines. See https://github.com/koalaman/shellcheck/wiki/SC2086
IFS=':' read -ra backup_paths <<< "$RESTIC_BACKUP_PATHS"
IFS=' ' read -ra extra_args <<< "$RESTIC_BACKUP_EXTRA_ARGS"


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
{ backup_output=$(restic backup \
	--verbose="$RESTIC_VERBOSITY_LEVEL" \
	--one-file-system \
	--tag "$RESTIC_BACKUP_TAG" \
	--option b2.connections="$B2_CONNECTIONS" \
	"${exclusion_args[@]}" \
	"${extra_args[@]}" \
	"${backup_paths[@]}" \
	| tee /dev/fd/3 & )  # store output in var for further proc; also tee to a temp fd that's redirected to stdout
} 3>&1
wait $!

# Dereference and delete/prune old backups.
# See restic-forget(1) or http://restic.readthedocs.io/en/latest/060_forget.html
# --group-by only the tag and path, and not by hostname. This is because I create a B2 Bucket per host, and if this hostname accidentially change some time, there would now be multiple backup sets.
restic forget \
	--verbose="$RESTIC_VERBOSITY_LEVEL" \
	--tag "$RESTIC_BACKUP_TAG" \
	--option b2.connections="$B2_CONNECTIONS" \
	--prune \
	--group-by "paths,tags" \
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

#
# (optionally) Notify about backup summary stats.
#
# How to perform the notification is up to the user; the script only writes the info to the user-owned file in a fire
# and forget fashion.
#
# One option to trigger desktop notifications on user-side is using a special FIFO file (a.k.a. pipe file), which will
# work as a queue; plus, a user process to read from that queue and run a desktop notification command.
#
# TODO Clean/or rephrase the example comments below
# In this case I'm running a user process that reads from a special pipe file and sends a desktop notification using
# `notify-send`.
# 
# See: https://github.com/gerardbosch/dotfiles-linux/blob/main/home/.config/autostart/notification-queue.desktop and
#      https://github.com/gerardbosch/dotfiles-linux/blob/main/home/bin/notification-queue-start-processing
#
if [ "$RESTIC_NOTIFY_BACKUP_STATS" = true ]; then
	if [ -w "$RESTIC_BACKUP_NOTIFICATION_FILE" ]; then
		added=$(grep -i 'Added to the repo:' <<< "$backup_output" | sed -E 's/.*dded to the repo: (.*)/\1/')
		# sample:  processed N files, N.XYZ GiB in H:mm
		size=$(grep  -i 'processed.*files,'  <<< "$backup_output" | sed -E 's/.*rocessed.*files, (.*) in.*/\1/g')
		echo "Added: ${added}. Snapshot size: ${size}" >> "$RESTIC_BACKUP_NOTIFICATION_FILE"
	else
		echo "[WARN] Couldn't write the backup summary stats. File not found or not writable: ${RESTIC_BACKUP_NOTIFICATION_FILE}"
	fi
fi

