#!/usr/bin/env bash
# Make backup my system with restic to Backblaze B2.
# This script is typically run by: /etc/systemd/system/restic-backup.{service,timer}

# Exit on failure, pipe failure
set -e -o pipefail

# Redirect stdout ( > ) into a named pipe ( >() ) running "tee" to a file, so we can observe the status by simply tailing the log file.
me=$(basename "$0")
now=$(date +%F_%R)
log_dir=/var/local/log/restic
log_file="${log_dir}/${now}_${me}.$$.log"
test -d $log_dir || mkdir -p $log_dir
exec > >(tee -i $log_file)
exec 2>&1

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock
}
trap exit_hook INT TERM

RETENTION_DAYS=7
RETENTION_WEEKS=12
RETENTION_MONTHS=18
RETENTION_YEARS=4

BACKUP_PATHS="/ /boot /home /mnt/media"
BACKUP_EXCLUDES="--exclude-file /.rsync_exclude --exclude-file /mnt/media/.rsync_exclude --exclude-file /home/erikw/.rsync_exclude"
BACKUP_TAG=systemd.timer

# Set all environment variables like
# B2_ACCOUNT_ID, B2_ACCOUNT_KEY, RESTIC_REPOSITORY etc.
source /etc/restic/b2_env.sh


# NOTE start all commands in background and wait for them to finish.
# Reason: bash ignores any signals while child process is executing and thus my trap exit hook is not triggered.
# However if put in subprocesses, wait(1) waits until the process finishes OR signal is received.
# Reference: https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash

# Remove locks from other stale processes to keep the automated backup running.
restic unlock &
wait $!

# See restic-backup(1) or http://restic.readthedocs.io/en/latest/040_backup.html
#restic backup --tag $BACKUP_TAG --one-file-system $BACKUP_EXCLUDES $BACKUP_PATHS &
#wait $!

# Until 
# https://github.com/restic/restic/issues/1557
# is fixed with the PR
# https://github.com/restic/restic/pull/1494
# we have to use a work-around and skip the --one-file-system and explicitly black-list the paths we don't want, as described here
# https://forum.restic.net/t/full-system-restore/126/8?u=fd0
restic backup \
	--tag $BACKUP_TAG \
	--exclude-file /.restic-excludes \
	$BACKUP_EXCLUDES \
	/ &
wait $!

# See restic-forget(1) or http://restic.readthedocs.io/en/latest/060_forget.html
restic forget \
	--tag $BACKUP_TAG \
	--keep-daily $RETENTION_DAYS \
	--keep-weekly $RETENTION_WEEKS \
	--keep-monthly $RETENTION_MONTHS \
	--keep-yearly $RETENTION_YEARS &
wait $!

# Remove old data not linked anymore.
# See restic-prune(1) or http://restic.readthedocs.io/en/latest/060_forget.html
restic prune &
wait $!


# Check repository for errors.
# NOTE this takes much time (and data transfer from remote repo?), do this in a separate systemd.timer which is run less often.
#restic check &
#wait $!
