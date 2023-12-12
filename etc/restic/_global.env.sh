# shellcheck shell=sh

# Global environment variables
# These variables are sourced FIRST, and any values inside of *.env.sh files for
# specific configurations will override if also defined there.


# Official instructions on how to setup the restic variables for Backblaze B2 can be found at
# https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#backblaze-b2


# The restic repository encryption key
export RESTIC_PASSWORD_FILE="{{ INSTALL_PREFIX }}/etc/restic/pw.txt"
# The global restic exclude file
export RESTIC_BACKUP_EXCLUDE_FILE="{{ INSTALL_PREFIX }}/etc/restic/backup_exclude.txt"

# Backblaze B2 credentials keyID & applicationKey pair.
# Restic environment variables are documented at https://restic.readthedocs.io/en/latest/040_backup.html#environment-variables
export B2_ACCOUNT_ID="<b2-key-id>"   # *EDIT* fill with your keyID
export B2_ACCOUNT_KEY="<b2-application-key>" # *EDIT* fill with your applicationKey

# How many network connections to set up to B2. Default is 5.
export B2_CONNECTIONS=10

# Optional extra space-separated args to restic-backup.
# This is empty here and profiles can override this after sourcing this file.
export RESTIC_BACKUP_EXTRA_ARGS=

# Verbosity level from 0-3. 0 means no --verbose.
# Override this value in a profile if needed.
export RESTIC_VERBOSITY_LEVEL=0

# (optional, uncomment to enable) Backup summary stats log: snapshot size, etc. (empty/unset won't log)
#export RESTIC_BACKUP_STATS_DIR="{{ INSTALL_PREFIX }}/var/log/restic-automatic-backup-scheduler"

# (optional) Desktop notifications. See README and restic_backup.sh for details on how to set this up (empty/unset means disabled)
export RESTIC_BACKUP_NOTIFICATION_FILE=
