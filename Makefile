# Not file targets.
.PHONY: help install install-scripts install-conf install-systemd uninstall

### Macros ###
DEFAULT_BRANCH = master
SRCS_SCRIPTS	= $(filter-out %cron_mail, $(wildcard usr/local/sbin/*))
# $(sort) remove duplicates that comes from running make install >1 times.
SRCS_CONF	= $(sort $(patsubst %.template, %, $(wildcard etc/restic/*)))
SRCS_SYSTEMD	= $(wildcard etc/systemd/system/*)

# To change the installation root path, set the PREFIX variable in your shell's environment, like:
# $ PREFIX=/usr/local make install
# $ PREFIX=/tmp/test make install
DEST_SCRIPTS	= $(PREFIX)/usr/local/sbin
DEST_CONF	= $(PREFIX)/etc/restic
DEST_SYSTEMD	= $(PREFIX)/etc/systemd/system
DEST_CURRENT_VERSION_FILE = $(PREFIX)/var/local/restic/current-version

INSTALLED_FILES = $(addprefix $(PREFIX)/, $(SRCS_SCRIPTS) $(SRCS_CONF) $(SRCS_SYSTEMD) $(DEST_CURRENT_VERSION_FILE))

### Targets ###
# target: all - Default target.
all: install

# target: help - Display all targets.
help:
	@egrep "#\starget:" [Mm]akefile  | sed 's/\s-\s/\t\t\t/' | cut -d " " -f3- | sort -d

# target: install - Install all files
install: install-scripts install-conf install-systemd install-current-version-file


# target: install-scripts - Install executables.
install-scripts:
	install -d $(DEST_SCRIPTS)
	install -m 0744 $(SRCS_SCRIPTS) $(DEST_SCRIPTS)

# Copy templates to new files with restricted permissions.
# Why? Because the non-template files are git-ignored to prevent that someone who clones or forks this repo checks in their sensitive data like the B2 password!
etc/restic/_global.env etc/restic/default.env etc/restic/pw.txt:
	install -m 0600 $@.template $@

# target: install-conf - Install restic configuration files.
# will create these files locally only if they don't already exist
# `|` means that dependencies are order-only, i.e. only created if they don't already exist.
install-conf: | $(SRCS_CONF)
	install -d $(DEST_CONF)
	install -b -m 0600 $(SRCS_CONF) $(DEST_CONF)
	$(RM) etc/restic/_global.env etc/restic/default.env etc/restic/pw.txt

# target: install-systemd - Install systemd timer and service files.
install-systemd:
	install -d $(DEST_SYSTEMD)
	install -m 0644 $(SRCS_SYSTEMD) $(DEST_SYSTEMD)

install-current-version-file:
	install -d $$(dirname $(DEST_CURRENT_VERSION_FILE))
	git rev-parse --short HEAD > $(DEST_CURRENT_VERSION_FILE)

# target: uninstall - Uninstall ALL files from the install targets.
uninstall:
	@for file in $(INSTALLED_FILES); do \
			echo $(RM) $$file; \
			$(RM) $$file; \
	done

# target: upgrade - Upgrade installation.
# .ONESHELL runs the script in a single shell instead of a shell per line; so no semicolons, nor backslashes required :)
.ONESHELL:
upgrade:
	@if [ $$(git branch --show-current) != $(DEFAULT_BRANCH) ] || ! git diff --quiet; then
		echo "Error: You can only upgrade from a clean working tree @ $(DEFAULT_BRANCH) branch."
		exit 1
	else
		user=$$(logname)  # as Makefile runs on sudo, get the user behind it
		echo "[NOTE] In case you cloned the repo via SSH, and your key is encrypted, you will be prompted for your SSH private-key passphrase. If that happens, abort (Ctrl-C) and run again using \`sudo -E\`.";
		sudo -E -u $$user git fetch --verbose

		# 0. Check for updates
		if git diff origin/$(DEFAULT_BRANCH) --quiet; then
			echo ""
			echo "You are already at the latest version. Nothing to do."
			exit 0
		fi

		# 1. Backup configs
		echo ""
		echo "Backing up..."
		echo "Your current config files are being backed up as $(DEST_CONF)/FILE~"
		for conf in $(filter-out %~, $(wildcard $(DEST_CONF)/*)); do
			echo "Backing up $$conf"
			cp -i $$conf $(DEST_CONF)/$$(basename $$conf)~
		done

		# 2.1. Checkout the currently installed version to assure files being uninstalled match current installation
		git checkout --quiet $$(cat $(DEST_CURRENT_VERSION_FILE))

		# 2.2. Uninstall
		echo ""
		echo "Uninstalling..."
		sudo -E make uninstall

		# 3.1. Switch back to default branch
		git checkout --quiet $(DEFAULT_BRANCH)

		# 3.2. Update repository
		echo ""
		echo "Updating repository..."
		sudo -E -u $$(logname) git pull;

		# 4. Reinstall
		echo ""
		echo "Reinstalling..."
		sudo -E make install

		# 5. Re-populate configs
		_helper/post-upgrade-config.sh $(DEST_CONF) $(DEST_CONF)/pw.txt $(DEST_CONF)/backup_exclude
		echo ""
		echo "FINISHED! Please, carefully verify that ALL your config values/profiles in $(DEST_CONF) were properly set."
		echo "  In case you added any line or uncommented optional features, you will need to manually add it."
		echo "  Additionally you can test restic: restic snapshots".
	fi
