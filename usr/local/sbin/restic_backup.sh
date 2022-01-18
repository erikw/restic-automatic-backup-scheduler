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

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock
}
trap exit_hook INT TERM

## Additonal service: if /home is being backed up, allow user specify backup files in home directory or default $XDG_CONFIG_HOME path
exclusion_args_from_homedirs() {
	local homeroot="$1"
	local args=""
	if [[ $BACKUP_PATHS == *"$homeroot"* ]]; then
		for homedir in $homeroot/*; do
			excl_home="$homedir/.backup_exclude"
			excl_xdg="$homedir/.config/restic/backup_exclude"
			test -f $excl_home && args+=" --exclude-file $excl_home"
			test -f $excl_xdg && args+=" --exclude-file $excl_xdg"
		done
	fi
	echo "$args"
}

# Remove duplicate entries by sorting them
sort_unique() {
  local paths="$1"
  # `sort -u` removes duplicates,  `xargs` trims trailing space
  echo $(tr ' ' '\n' <<< "$paths" | sort -u | tr '\n' ' ' | xargs)
}

# Set up exclude files: global + path-specific ones + home directories.
# NOTE that restic will fail the backup if not all listed --exclude-files exist. Thus we should only list them if they are really all available.
##  Global backup configuration.
exclusion_args="--exclude-file ${RESTIC_BACKUP_EXCLUDE}"
## Self-contained backup files per backup path. E.g. having an USB disk at /mnt/media in BACKUP_PATHS, then it can have a /mnt/media/.backup_exclude
for backup_path in ${BACKUP_PATHS[@]}; do
	if [ -f "$backup_path/.backup_exclude" ]; then
		exclusion_args+=" --exclude-file $backup_path/.backup_exclude"
	fi
done
exclusion_args+="$(exclusion_args_from_homedirs /home)"
## And the same service of macOS users, having /Users instead of /home
exclusion_args+="$(exclusion_args_from_homedirs /Users)"
exclusion_args=$(sort_unique "$exclusion_args")  # remove duplicate entries caused by having /home/user as backup path

# NOTE start all commands in background and wait for them to finish.
# Reason: bash ignores any signals while child process is executing and thus the trap exit hook is not triggered.
# However if put in subprocesses, wait(1) waits until the process finishes OR signal is received.
# Reference: https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash

# Remove locks from other stale processes to keep the automated backup running.
restic unlock &
wait $!

# Do the backup!
# See restic-backup(1) or http://restic.readthedocs.io/en/latest/040_backup.html
# --one-file-system makes sure we only backup exactly those mounted file systems specified in $BACKUP_PATHS, and thus not directories like /dev, /sys etc.
# --tag lets us reference these backups later when doing restic-forget.
restic backup \
	--verbose \
	--one-file-system \
	--tag $BACKUP_TAG \
	--option b2.connections=$B2_CONNECTIONS \
	$exclusion_args \
	$BACKUP_PATHS &
wait $!

# Dereference and delete/prune old backups.
# See restic-forget(1) or http://restic.readthedocs.io/en/latest/060_forget.html
# --group-by only the tag and path, and not by hostname. This is because I create a B2 Bucket per host, and if this hostname accidentially change some time, there would now be multiple backup sets.
restic forget \
	--verbose \
	--tag $BACKUP_TAG \
	--option b2.connections=$B2_CONNECTIONS \
	--prune \
	--group-by "paths,tags" \
	--keep-daily $RETENTION_DAYS \
	--keep-weekly $RETENTION_WEEKS \
	--keep-monthly $RETENTION_MONTHS \
	--keep-yearly $RETENTION_YEARS &
wait $!

# Check repository for errors.
# NOTE this takes much time (and data transfer from remote repo?), do this in a separate systemd.timer which is run less often.
#restic check &
#wait $!

echo "Backup & cleaning is done."
