# Automatic restic backups using systemd services and timers
[![GitHub Stars](https://img.shields.io/github/stars/erikw/restic-systemd-automatic-backup?style=social)](#)
[![GitHub Forks](https://img.shields.io/github/forks/erikw/restic-systemd-automatic-backup?style=social)](#)
<br>
[![AUR version](https://img.shields.io/aur/version/restic-systemd-automatic-backup)](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/)
[![AUR maintainer](https://img.shields.io/aur/maintainer/restic-systemd-automatic-backup?label=AUR%20maintainer)](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/)
[![Open issues](https://img.shields.io/github/issues/erikw/restic-systemd-automatic-backup)](https://github.com/erikw/restic-systemd-automatic-backup/issues)
[![Closed issues](https://img.shields.io/github/issues-closed/erikw/restic-systemd-automatic-backup?color=success)](https://github.com/erikw/restic-systemd-automatic-backup/issues?q=is%3Aissue+is%3Aclosed)
[![Closed PRs](https://img.shields.io/github/issues-pr-closed/erikw/restic-systemd-automatic-backup?color=success)](https://github.com/erikw/restic-systemd-automatic-backup/pulls?q=is%3Apr+is%3Aclosed)
[![License](https://img.shields.io/badge/license-BSD--3-blue)](LICENSE)
[![OSS Lifecycle](https://img.shields.io/osslifecycle/erikw/restic-systemd-automatic-backup)](https://github.com/Netflix/osstracker)
[![Latest tag](https://img.shields.io/github/v/tag/erikw/restic-systemd-automatic-backup)](https://github.com/erikw/restic-systemd-automatic-backup/tags)
<br>

[![Contributors](https://img.shields.io/github/contributors/erikw/restic-systemd-automatic-backup)](https://github.com/erikw/restic-systemd-automatic-backup/graphs/contributors) including these top contributors:
<a href = "https://github.com/erikw/restic-systemd-automatic-backup/graphs/contributors">
<img src = "https://contrib.rocks/image?repo=erikw/restic-systemd-automatic-backup&max=24"/>
</a>

# Intro

[restic](https://restic.net/) is a command-line tool for making backups, the right way. Check the official website for a feature explanation. As a storage backend, I recommend [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html) as restic works well with it, and it is (at the time of writing) very affordable for the hobbyist hacker!

Unfortunately restic does not come pre-configured with a way to run automated backups, say every day. However it's possible to set this up yourself using systemd/cron and some wrappers. This example also features email notifications when a backup fails to complete.

Here follows a step-by step tutorial on how to set it up, with my sample script and configurations that you can modify to suit your needs.

Note, you can use any of the supported [storage backends](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html). The setup should be similar but you will have to use other configuration variables to match your backend of choice.

# Requirements
* `restic >=v0.9.6`

# TL;DR Setup
1. Create B2 credentials as instructed [below](#1-create-backblaze-b2-account)
1. Install config and scripts:
   ```console
   $ sudo make install
   ```
1. Fill out configuration values:
   * `/etc/restic/pw.txt` - Contains the password to be used by restic to encrypt the repository files. Should be different than your B2 password!
   * `/etc/restic/_global.env` - Global environment variables.
   * `/etc/restic/default.env` - Profile specific environment variables (multiple profiles can be defined by copying to `/etc/restic/something.env`).
1. Initialize remote repo as described [below](#3-initialize-remote-repo)
1. Run backup using Systemd, and enable it for starting with the system:
   ```console
   $ sudo systemctl start restic-backup@default.timer
   $ sudo systemctl enable restic-backup@default.timer
   ```
1. Watch its progress with Systemd journal:
   ```console
   $ journalctl -f --lines=50 -u restic-backup@default
   ```
1. Verify the backup
   ```console
   $ sudo -i
   $ source /etc/restic/default.env
   $ restic snapshots
   ```
1. (optional) Define multiple profiles: just make a copy of the `default.env` and use the defined profile name in place of `default` to run backups or enable timers. Notice that the value after `@` works as a parameter.
1. (optional) Enable the check job that verifys that the backups for the profile are all intact.
   ```console
   $ sudo systemctl start restic-check@default.timer
   $ sudo systemctl enable restic-check@default.timer
   ````
1. (optional) Setup email on failure as described [here](#8-email-notification-on-failure)

# Step-by-step and manual setup
This is a more detailed explanation than the TL;DR section that will give you more understanding in the setup, and maybe inspire you to develop your own setup based on this one even!

Tip: The steps in this section will instruct you to copy files from this repo to system directories. If you don't want to do this manually, you can use the Makefile:

```console
$ git clone https://github.com/erikw/restic-systemd-automatic-backup.git && cd $(basename "$_" .git)
$ sudo make install
````

Arch Linux users can install the aur package [restic-systemd-automatic-backup](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/) e.g.:
```console
$ yaourt -S restic-systemd-automatic-backup
````

## 1. Create Backblaze B2 account

First, see this official Backblaze [tutorial](https://help.backblaze.com/hc/en-us/articles/115002880514-How-to-configure-Backblaze-B2-with-Restic-on-Linux) on restic, and follow the instructions ("Create Backblaze account with B2 enabled") there on how to create a new B2 bucket.

Take note of the your account ID, application key and password for the next steps.


## 2. Configure your B2 account locally

> **Attention!** Going the manual way requires that most of the following commands are run as root.

Put these files in `/etc/restic/`:
* `default.env`: Fill this file out with your B2 bucket settings etc. The reason for putting these in a separate file is that it can be used also for you to simply source, when you want to issue some restic commands. For example:
   ```console
   $ source /etc/restic/default.env
   $ restic snapshots    # You don't have to supply all parameters like --repo, as they are now in your environment!
   ````
* `pw.txt`: This file should contain the restic password used to encrypt the repository. This is a new password what soon will be used when initializing the new repository. It should be unique to this restic backup repository and is needed for restoring from it. Don't re-use your B2 login password, this should be different.

## 3. Initialize remote repo
Now we must initialize the repository on the remote end:
```console
$ sudo -i
$ source /etc/restic/default.env
$ restic init
```

## 4. Script for doing the backup
Put this file in `/usr/local/sbin`:
* `restic_backup.sh`: A script that defines how to run the backup. Edit this file to respect your needs in terms of backup which paths to backup, retention (number of backups to save), etc.

Copy this file to `/etc/restic/backup_exclude` or `~/.backup_exclude`:
* `.backup_exclude`: A list of file pattern paths to exclude from you backups, files that just occupy storage space, backup-time, network and money.
  Aside from system-wide exclusions, every user can define their own ones at `~/.backup_exclude`.

## 5. Make first backup 
Now see if the backup itself works, by running as root

```console
$ sudo -i
$ source /etc/restic/default.env
$ /usr/local/sbin/restic_backup.sh
````

## 6. Verify the backup
As the `default.env` is already sourced in your root shell, you can now just list the snapshos
```console
$ sudo -i
$ source /etc/restic/default.env
$ restic snapshots
```

Alternatively you can mount the restic snapshots to a directory set `/mnt/restic`
```console
$ restic mount /mnt/restic
$ ls /mnt/restic
```

## 7. Backup automatically; systemd service + timer
Now we can do the modern version of a cron-job, a systemd service + timer, to run the backup every day!

Put these files in `/etc/systemd/system/`:

* `restic-backup@.service`: A service that calls the backup script with the specified profile. The profile is specified
  by the value after `@` when running it (see below).
* `restic-backup@.timer`: A timer that starts the former backup every day (same thing about profile here).

Now simply enable the timer with:
```console
$ systemctl start restic-backup@default.timer
$ systemctl enable restic-backup@default.timer
````

 ☝ **Note**: You can run it with different values instead of `default` if you use multiple profiles.

You can see when your next backup is scheduled to run with
```console
$ systemctl list-timers | grep restic
```

and see the status of a currently running backup with

```console
$ systemctl status restic-backup
```

or start a backup manually

```console
$ systemctl start restic-backup@default
```

You can follow the backup stdout output live as backup is running with:

```console
$ journalctl -f -u restic-backup@default.service
````

(skip `-f` to see all backups that has run)



## 8. Email notification on failure
We want to be aware when the automatic backup fails, so we can fix it. Since my laptop does not run a mail server, I went for a solution to set up my laptop to be able to send emails with [postfix via my Gmail](https://easyengine.io/tutorials/linux/ubuntu-postfix-gmail-smtp/). Follow the instructions over there.

Put this file in `/usr/local/sbin`:
* `systemd-email`: Sends email using sendmail(1). This script also features time-out for not spamming Gmail servers and getting my account blocked.

Put this files in `/etc/systemd/system/`:
* `status-email-user@.service`: A service that can notify you via email when a systemd service fails. Edit the target email address in this file.

As you maybe noticed already before, `restic-backup.service` is configured to start `status-email-user.service` on failure.


## 9. Optional: automated backup checks
Once in a while it can be good to do a health check of the remote repository, to make sure it's not getting corrupt. This can be done with `$ restic check`.

There are some `*check*`-files in this git repo. Install these in the same way you installed the `*-backup*`-files and enable with sytemd

```console
$ sudo -i
$ systemctl start restic-check@default.timer
$ systemctl enable restic-check@default.timer
````



# Cron?
If you want to run an all-classic cron job instead, do like this:

* `etc/cron.d/restic`: Depending on your system's cron, put this in `/etc/cron.d/` or similar, or copy the contents to $(sudo crontab -e). The format of this file is tested under FreeBSD, and might need adaptions depending on your cron.
* `usr/local/sbin/cron_mail`: A wrapper for running cron jobs, that sends output of the job as an email using the mail(1) command.

# Uninstall

There is a make target to remove all files (scripts and configs) that were installed by `sudo make install`. Just run:

```console
$ sudo make uninstall
```

# Variations
A list of variations of this setup:
* Using `--files-from` [#44](https://github.com/erikw/restic-systemd-automatic-backup/issues/44)

# Development
To not mess up your real installation when changing the `Makefile` simply install to a `$PREFIX` like
```console
$ PREFIX=/tmp/restic-test make install
```
