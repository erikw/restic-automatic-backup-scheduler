# Automatic restic backups using systemd services and timers

## Restic

[restic](https://restic.net/) is a command-line tool for making backups, the right way. Check the official website for a feature explanation. As a storage backend, I recommend [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html) as restic works well with it, and it is (at the time of writing) very affordable for the hobbyist hacker!

First, see this official Backblaze [tutorial](https://help.backblaze.com/hc/en-us/articles/115002880514-How-to-configure-Backblaze-B2-with-Restic-on-Linux) on restic, on how to setup your B2 bucket.

## Automatic scheduled backups
Unfortunately restic does not come per-configured with a way to run automated backups, say every day. However it's possible to set this up yourself using. This example also features email notifications when a backup fails to complete.

Put this file in `/etc/restic/`:
* `b2_env.sh`: Fill this file out with your B2 bucket settings etc. The reason for putting these in a separeate file is that it can be used also for you to simply source, when you want to issue some restic commands. For example:
```bash
$ source /etc/restic/b2_env.sh
$ restic snapshots    # You don't have to supply all paramters like --repo, as they are now in your envionment!
````
* `b2_pw.txt`: Put your b2 password in this file.

Put these files in `/usr/local/sbin`:
* `restic_backup.sh`: A script that defines how to run the backup. Edit this file to respect your needs in terms of backup which paths to backup, retention (number of bakcups to save), etc.
* `systemd-email`: Sends email using sendmail. You must set up your computer so it can send mail, for example using [postfix and Gmail](https://easyengine.io/tutorials/linux/ubuntu-postfix-gmail-smtp/). This script also  features time-out for not spamming Gmail servers. Edit the email target address in this file.


Put these files in `/etc/systemd/system/`:
* `restic-backup.service`: A service that calls the script above.
* `restic-backup.timer`: A timer (systemd's cronjobs) that starts the backup every day.
* `status-email-user@.service`: A service that can notify you via email when a systemd service fails.


Now simply enable the timer with:
```bash
$ systemctl enable restic-backup.timer
````
and enjoy your computer being backed up every day!

You can see when your next backup will be schedued
```bash
$ systemctl list-timers | grep restic
```

## Automatic backup checks

Furthermore there are some `*-check*`-files in this repo too. Install these too if you want to run restic-check once in a while to verify that your remote backup is not corrupt.
