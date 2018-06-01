# B2 credentials.
# Extracted settings so both systemd timers and user can just source this when want to work on my B2 backup.
# See https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html

export RESTIC_REPOSITORY="b2:<b2-repo-name>"
export RESTIC_PASSWORD_FILE="/etc/restic/b2_pw.txt"
export B2_ACCOUNT_ID="<b2-account-id>"
export B2_ACCOUNT_KEY="<b2-account-key>"
