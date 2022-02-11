# Automatic restic backups using systemd services and timers
[![GitHub Stars](https://img.shields.io/github/stars/erikw/restic-systemd-automatic-backup?style=social)](#)
[![GitHub Forks](https://img.shields.io/github/forks/erikw/restic-systemd-automatic-backup?style=social)](#)
<br>
[![Lint Code Base](https://github.com/erikw/restic-systemd-automatic-backup/actions/workflows/linter.yml/badge.svg)](https://github.com/erikw/restic-systemd-automatic-backup/actions/workflows/linter.yml)
[![Latest tag](https://img.shields.io/github/v/tag/erikw/restic-systemd-automatic-backup)](https://github.com/erikw/restic-systemd-automatic-backup/tags)
[![AUR version](https://img.shields.io/aur/version/restic-systemd-automatic-backup)](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/)
[![AUR maintainer](https://img.shields.io/aur/maintainer/restic-systemd-automatic-backup?label=AUR%20maintainer)](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/)
[![Homebrew Formula](https://img.shields.io/badge/homebrew-erikw%2Ftap-orange)](https://github.com/erikw/homebrew-tap)
[![Open issues](https://img.shields.io/github/issues/erikw/restic-systemd-automatic-backup)](https://github.com/erikw/restic-systemd-automatic-backup/issues)
[![Closed issues](https://img.shields.io/github/issues-closed/erikw/restic-systemd-automatic-backup?color=success)](https://github.com/erikw/restic-systemd-automatic-backup/issues?q=is%3Aissue+is%3Aclosed)
[![Closed PRs](https://img.shields.io/github/issues-pr-closed/erikw/restic-systemd-automatic-backup?color=success)](https://github.com/erikw/restic-systemd-automatic-backup/pulls?q=is%3Apr+is%3Aclosed)
[![License](https://img.shields.io/badge/license-BSD--3-blue)](LICENSE)
[![OSS Lifecycle](https://img.shields.io/osslifecycle/erikw/restic-systemd-automatic-backup)](https://github.com/Netflix/osstracker)
<br>

[![Contributors](https://img.shields.io/github/contributors/erikw/restic-systemd-automatic-backup)](https://github.com/erikw/restic-systemd-automatic-backup/graphs/contributors) including these top contributors:
<a href = "https://github.com/erikw/restic-systemd-automatic-backup/graphs/contributors">
<img src = "https://contrib.rocks/image?repo=erikw/restic-systemd-automatic-backup&max=24"/>
</a>

# Intro
[restic](https://restic.net/) is a command-line tool for making backups, the right way. Check the official website for a feature explanation. As a storage backend, I recommend [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html) as restic works well with it, and it is (at the time of writing) very affordable for the hobbyist hacker! (anecdotal: I pay for my full-systems backups each month typically < 1 USD).

Unfortunately restic does not come pre-configured with a way to run automated backups, say every day. However it's possible to set this up yourself using systemd/cron and some wrappers. This example also features email notifications when a backup fails to complete.

Here follows a step-by step tutorial on how to set it up, with my sample script and configurations that you can modify to suit your needs.

Note, you can use any of the supported [storage backends](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html). The setup should be similar but you will have to use other configuration variables to match your backend of choice.

## Project Scope
The scope for this is not to be a full-fledged super solution that solves all the problems and all possible setups. The aim is to be a hackable code base for you to start sewing up the perfect backup solution that fits your requirements!

Nevertheless the project should work out of the box, be minimal but still open the doors for configuration and extensions by users.

## Navigate this README
Tip: use the Section icon in the top left of this document to navigate the sections.

![README Sections](img/readme_sections.png)


# Requirements
* `restic >=v0.9.6`
* `bash >=v4.0.0`
* (recommended)  GNU `make` if you want an automated install
  * Arch: part of the `base-devel` meta package, Debian/Ubuntu: part of the `build-essential` meta package, macOS: use the preinstalled or a more recent with Homebrew)


# Setup
Depending on your system, the setup will look different. Choose one of
* <img height="16" width="16" src="https://unpkg.com/simple-icons@v6/icons/linux.svg" /> [Linux + Systemd](#setup-linux-systemd)
* <img height="16" width="16" src="https://unpkg.com/simple-icons@v6/icons/apple.svg" /> [macOS + LaunchAgent](#setup-macos-launchagent)
* <img height="16" width="16" src="https://unpkg.com/simple-icons@v6/icons/clockify.svg" /> [Cron](#setup-cron) - for any system having a cron daemon. Tested on FreeBSD and macOS.

## Setup Linux Systemd
### TL;DR Setup
1. Create B2 credentials as instructed [below](#1-create-backblaze-b2-account)
1. Install config and scripts:
   ```console
   $ sudo make install-systemd
   ```
   ☝ **Note**: `sudo` is required here, as some files are installed into system directories (`/etc/`
   and `/usr/bin`). Have a look to the `Makefile` to know more.
1. Fill out configuration values (edit with sudo):
   * `/etc/restic/pw.txt` - Contains the password (single line) to be used by restic to encrypt the repository files. Should be different than your B2 password!
   * `/etc/restic/_global.env.sh` - Global environment variables.
   * `/etc/restic/default.env.sh` - Profile specific environment variables (multiple profiles can be defined by copying to `/etc/restic/something.env.sh`).
   * `/etc/restic/backup_exclude.txt` - List of file patterns to ignore. This will trim down your backup size and the speed of the backup a lot when done properly!
1. Initialize remote repo as described [below](#3-initialize-remote-repo)
1. Configure [how often](https://www.freedesktop.org/software/systemd/man/systemd.time.html#Calendar%20Events) back up should be made.
   * Edit if needed `OnCalendar` in `/usr/lib/systemd/system/restic-backup@.timer`.
1. Enable automated backup for starting with the system (`enable` creates symlinks):
   ```console
   $ sudo systemctl enable --now restic-backup@default.timer
   ```
1. And run an immediate backup if you want (if not, it will run on daily basis):
   ```console
   $ sudo systemctl start restic-backup@default
   ```
1. Watch its progress with Systemd journal:
   ```console
   $ journalctl -f --lines=50 -u restic-backup@default
   ```
1. Verify the backup
   ```console
   $ sudo -i
   $ source /etc/restic/default.env.sh
   $ restic snapshots
   ```
1. (optional) Define multiple profiles: just make a copy of the `default.env.sh` and use the defined profile name in place of `default` to run backups or enable timers. Notice that the value after `@` works as a parameter.
1. (optional) Enable the check job that verifies that the backups for the profile are all intact.
   ```console
   $ sudo systemctl enable --now restic-check@default.timer
   ````
1. (optional) Setup email on failure as described [here](#8-email-notification-on-failure)


### Step-by-step and manual setup
This is a more detailed explanation than the TL;DR section that will give you more understanding in the setup, and maybe inspire you to develop your own setup based on this one even!

Tip: The steps in this section will instruct you to copy files from this repo to system directories. If you don't want to do this manually, you can use the Makefile:

```console
$ git clone https://github.com/erikw/restic-systemd-automatic-backup.git && cd $(basename "$_" .git)
$ sudo make install-systemd
````

If you want to install everything manually, we will install files to `/etc`, `/bin`, and not use the `$make install-systemd` command, then you need to clean up a placeholder `$INSTALL_PREFIX` in the souce files first by running:
```console
$ find etc bin -type f -exec sed -i.bak -e 's|$INSTALL_PREFIX||g' {} \; -exec rm {}.bak \;
```
and you should now see that all files have been changed like e.g.
```diff
-export RESTIC_PASSWORD_FILE="$INSTALL_PREFIX/etc/restic/pw.txt"
+export RESTIC_PASSWORD_FILE="/etc/restic/pw.txt"
```
This prefix is there so that `make` users can set a different `$PREFIX` when installing like `PREFIX=/usr/local make install-systemd`. So if we don't use the makefile, we need to remove this prefix with the command above just.


Arch Linux users can install the aur package [restic-systemd-automatic-backup](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/) e.g.:
```console
$ yaourt -S restic-systemd-automatic-backup
````

#### 1. Create Backblaze B2 Account, Bucket and keys
First, see this official Backblaze [tutorial](https://help.backblaze.com/hc/en-us/articles/4403944998811-Quickstart-Guide-for-Restic-and-Backblaze-B2-Cloud-Storage) on restic, and follow the instructions ("Create Backblaze account with B2 enabled") there on how to create a new B2 bucket. In general, you'd want a private bucket, without B2 encryption (restic does the encryption client side for us) and without the object lock feature.

For restic to be able to connect to your bucket, you want to in the B2 settings create a pair of keyID and applicationKey. It's a good idea to create a separate pair of ID and Key with for each bucket that you will use, with limited read&write access to only that bucket.


#### 2. Configure your B2 credentials locally
> **Attention!** Going the manual way requires that most of the following commands are run as root.

Put these files in `/etc/restic/`:
* `_global.env.sh`: Fill this file out with your global settings including B2 keyID & applicationKey. A global exclude list is set here (explained in section below).
* `default.env.sh`: This is the default profile. Fill this out with bucket name, backup paths and retention policy. This file sources `_global.env.sh` and is thus self-contained and can be sourced in the shell when you want to issue some manual restic commands. For example:
   ```console
   $ source /etc/restic/default.env.sh
   $ restic snapshots    # You don't have to supply all parameters like --repo, as they are now in your environment!
   ````
* `pw.txt`: This file should contain the restic password used to encrypt the repository. This is a new password what soon will be used when initializing the new repository. It should be unique to this restic backup repository and is needed for restoring from it. Don't re-use your B2 login password, this should be different. For example you can generate a 128 character password (must all be on one line) with:
   ```console
   $ openssl rand -base64 128 | tr -d '\n' > /etc/restic/pw.txt
   ```

#### 3. Initialize remote repo
Now we must initialize the repository on the remote end:
```console
$ sudo -i
$ source /etc/restic/default.env.sh
$ restic init
```

#### 4. Script for doing the backup
Put this file in `/bin`:
* `restic_backup.sh`: A script that defines how to run the backup. The intention is that you should not need to edit this script yourself, but be able to control everything from the `*.env.sh` profiles.

Restic support exclude files. They list file pattern paths to exclude from you backups, files that just occupy storage space, backup-time, network and money. `restic_backup.sh` allows for a few different exclude files.
* `/etc/restic/backup_exclude.txt` - global exclude list. You can use only this one if your setup is easy. This is set in `_global.env.sh`. If you need a different file for another profile, you can override the envvar `RESTIC_BACKUP_EXCLUDE_FILE` in this profile.
* `.backup_exclude.txt` per backup path. If you have e.g. an USB disk mounted at /mnt/media and this path is included in the `$RESTIC_BACKUP_PATHS`, you can place a file `/mnt/media/.backup_exclude.txt` and it will automatically picked up. The nice thing about this is that the backup paths are self-contained in terms of what they shoud exclude!

#### 5. Make first backup
Now see if the backup itself works, by running as root

```console
$ sudo -i
$ source /etc/restic/default.env.sh
$ /bin/restic_backup.sh
````

#### 6. Verify the backup
As the `default.env.sh` is already sourced in your root shell, you can now just list the snapshos
```console
$ sudo -i
$ source /etc/restic/default.env.sh
$ restic snapshots
```

Alternatively you can mount the restic snapshots to a directory set `/mnt/restic`
```console
$ restic mount /mnt/restic
$ ls /mnt/restic
```

#### 7. Backup automatically; systemd service + timer
Now we can do the modern version of a cron-job, a systemd service + timer, to run the backup every day!

Put these files in `/etc/systemd/system` (note that the Makefile installs as package to `/usr/lib/systemd/system`)
* `restic-backup@.service`: A service that calls the backup script with the specified profile. The profile is specified
  by the value after `@` when running it (see below).
* `restic-backup@.timer`: A timer that starts the former backup every day (same thing about profile here).
   * If needed, edit this file to configure [how often](https://www.freedesktop.org/software/systemd/man/systemd.time.html#Calendar%20Events) back up should be made. See the `OnCalendar` key in the file.

Now simply enable the timer with:
```console
$ sudo systemctl enable --now restic-backup@default.timer
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



#### 8. Email notification on failure
We want to be aware when the automatic backup fails, so we can fix it. Since my laptop does not run a mail server, I went for a solution to set up my laptop to be able to send emails with [postfix via my Gmail](https://easyengine.io/tutorials/linux/ubuntu-postfix-gmail-smtp/). Follow the instructions over there.

Put this file in `/bin`:
* `systemd-email`: Sends email using sendmail(1). This script also features time-out for not spamming Gmail servers and getting my account blocked.

Put this files in `/etc/systemd/system/`:
* `status-email-user@.service`: A service that can notify you via email when a systemd service fails. Edit the target email address in this file.

As you maybe noticed already before, `restic-backup.service` is configured to start `status-email-user.service` on failure.


#### 9. Optional: automated backup checks
Once in a while it can be good to do a health check of the remote repository, to make sure it's not getting corrupt. This can be done with `$ restic check`.

There is companion scripts, service and timer (`*check*`) to restic-backup.sh that checks the restic backup for errors; look in the repo in `usr/lib/systemd/system/` and `bin/` and copy what you need over to their corresponding locations.

```console
$ sudo systemctl enable --now restic-check@default.timer
````

#### 10. Optional: 🏃 Restic wrapper
For convenience there's a `restic` wrapper script that makes loading profiles and **running restic**
straightforward (it needs to run with sudo to read environment). Just run:

- `sudo resticw WHATEVER` (e.g. `sudo resticw snapshots`) to use the default profile.
- You can run the wrapper by passing a specific profile: `resticw -p anotherprofile snapshots`.

##### Useful commands

| Command                                           | Description                                                       |
|---------------------------------------------------|-------------------------------------------------------------------|
| `resticw snapshots`                               | List backup snapshots                                             |
| `resticw diff <snapshot-id> latest`               | Show the changes from the latest backup                           |
| `resticw stats` / `resticw stats snapshot-id ...` | Show the statistics for the whole repo or the specified snapshots |
| `resticw mount /mnt/restic`                       | Mount your remote repository                                      |

## Setup macOS LaunchAgent
LaunchAgent is the modern service scheduler in in macOS that uses [Launchd](https://www.launchd.info/).
[Launchd](https://www.launchd.info/) is the modern built-in service scheduler in macOS. It has support for running services as root (Daemon) or as a normal user (Agent). Here we set up an LauchAgent to be run as your normal user for starting regular backups.

### Homebrew
With Homebrew you can easily install this project from the [erikw/homebrew-tap](https://github.com/erikw/homebrew-tap):
```console
$ brew install erikw/tap/restic-automatic-backup-scheduler
```

### Manual
1. In general, follow the same setup as in (#setup-linux-systemd) except for:
  * use `make install-launchagent` instead of `make install-systemd`
  * install everything to `/usr/local` and run restic as your own user, not root
  * Thus, install with
	```console
	$ PREFIX=/usr/local make install-launchagent
	```
1. After installation with `make` , edit the installed LaunchAgent if you want to change the default schedule or profile used:
	```console
	$ vim ~/Library/LaunchAgents/com.github.erikw.restic-automatic-backup.plist 
	```
1. Now install, enable and start the first run!
	```console
	$ launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.github.erikw.restic-automatic-backup.plist
	$ launchctl enable gui/$UID/com.github.erikw.restic-automatic-backup
	$ launchctl kickstart -p gui/$UID/com.github.erikw.restic-automatic-backup
	```
	As a convenience, a shortcut for the above commands are `$ make activate-launchagent`.

Use the `disable` command to temporarily pause the agent, or `bootout` to uninstall it.
```
$ launchctl disable gui/$UID/com.github.erikw.restic-automatic-backup
$ launchctl bootout gui/$UID/com.github.erikw.restic-automatic-backup
```

If you updated the `.plist` file, you need to issue the `bootout` followed by `bootrstrap` and `enable` sub-commands of `launchctl`. This will guarantee that the file is properly reloaded.

## Setup Cron
If you want to run an all-classic cron job instead, do like this:

1. Follow the main setup from [Step-by-step and manual setup](#step-by-step-and-manual-setup) but skip the systemd parts.
1. `etc/cron.d/restic`: Depending on your system's cron, put this in `/etc/cron.d/` or similar, or copy the contents to $(sudo crontab -e). The format of this file is tested under FreeBSD, and might need adaptions depending on your cron.
  * You can use `$ make install-cron` to copy it over to `/etc/cron.d`.
1. (Optional) `bin/cron_mail`: A wrapper for running cron jobs, that sends output of the job as an email using the mail(1) command.


# Uninstall
There is a make target to remove all files (scripts and configs) that were installed by `sudo make install-*`. Just run:

```console
$ sudo make uninstall
```

# Variations
A list of variations of this setup:
* Using `--files-from` [#44](https://github.com/erikw/restic-systemd-automatic-backup/issues/44)

# Development
* To not mess up your real installation when changing the `Makefile` simply install to a `$PREFIX` like
   ```console
   $ PREFIX=/tmp/restic-test make install-systemd
   ```
* **Updating the `resticw` parser:** If you ever update the usage `DOC`, you will need to refresh the auto-generated parser:
  ```console
  $ pip install doctopt.sh
  $ doctopt.sh usr/local/bin/resticw
  ```

# Releasing
To make a new release:
1.
   ```console
   $ vi CHANGELOG.md && git commit -am "Update CHANGELOG.md"
   $ git tag vX.Y.Z
   $ git push && git push --tags
   ```
1. Update version in the AUR [PKGBUILD](https://aur.archlinux.org/packages/restic-systemd-automatic-backup/).
1. Update version in the Homebrew [Formula](https://github.com/erikw/homebrew-tap/blob/main/Formula/restic-automatic-backup-scheduler.rb).
