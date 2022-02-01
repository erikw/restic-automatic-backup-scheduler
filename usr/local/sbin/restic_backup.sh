#!/usr/bin/env bash
# Make a backup with restic to Backblaze B2.
#
# This script is typically run (as root user) either like:
# - from restic service/timer: $PREFIX/etc/systemd/system/restic-backup.{service,timer}
# - from a cronjob: $PREFIX/etc/cron.d/restic
# - manually by a user. For it to work, the environment variables must be set in the shell where this script is executed
#   $ source $PREFIX/etc/default.env
#   $ restic_backup.sh

# Exit on error, unset var, pipe failure
set -euo pipefail

# Assert that all needed environment variables are set.
# TODO in future if this grows, move this to a restic_lib.sh
assert_envvars() {
	local varnames=("$@")
	for varname in "${varnames[@]}"; do
		# Check if variable is set, then if it is not empty (need to do both as of `set -u`).
		if [ -z ${!varname+x} ] || [ -z "${!varname}" ] ; then
			printf "%s must be set with a value for this script to work.\n\nDid you forget to source a /etc/restic/*.env profile in the current shell before executing this script?\n" "$varname" >&2
			exit 1
		fi
	done
}
assert_envvars \
	B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_CONNECTIONS \
	RESTIC_BACKUP_PATHS RESTIC_BACKUP_TAG \
	RESTIC_BACKUP_EXCLUDE_FILE RESTIC_BACKUP_EXTRA_ARGS RESTIC_PASSWORD_FILE RESTIC_REPOSITORY RESTIC_VERBOSITY_LEVEL \
	RESTIC_RETENTION_DAYS RESTIC_RETENTION_MONTHS RESTIC_RETENTION_WEEKS RESTIC_RETENTION_YEARS


# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock
}
trap exit_hook INT TERM

# Set up exclude files: global + path-specific ones
# NOTE that restic will fail the backup if not all listed --exclude-files exist. Thus we should only list them if they are really all available.
##  Global backup configuration.
exclusion_args="--exclude-file ${RESTIC_BACKUP_EXCLUDE_FILE}"
## Self-contained backup files per backup path. E.g. having an USB disk at /mnt/media in RESTIC_BACKUP_PATHS,
# a file /mnt/media/.backup_exclude.txt will automatically be detected and used:
for backup_path in ${RESTIC_BACKUP_PATHS[@]}; do
	if [ -f "$backup_path/.backup_exclude.txt" ]; then
		exclusion_args+=" --exclude-file $backup_path/.backup_exclude.txt"
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
restic backup \
	--verbose="$RESTIC_VERBOSITY_LEVEL" \
	--one-file-system \
	--tag "$RESTIC_BACKUP_TAG" \
	--option b2.connections="$B2_CONNECTIONS" \
	"$exclusion_args" \
	"$RESTIC_BACKUP_EXTRA_ARGS" \
	"$RESTIC_BACKUP_PATHS" &
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
