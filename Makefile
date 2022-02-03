# Not file targets.
.PHONY: help install install-scripts install-conf install-systemd uninstall

### Macros ###
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

INSTALLED_FILES = $(addprefix $(PREFIX)/, $(SRCS_SCRIPTS) $(SRCS_CONF) $(SRCS_SYSTEMD))

### Targets ###
# target: all - Default target.
all: install

# target: help - Display all targets.
help:
	@egrep "#\starget:" [Mm]akefile  | sed 's/\s-\s/\t\t\t/' | cut -d " " -f3- | sort -d

# target: install - Install all files
install: install-scripts install-conf install-systemd


# target: install-scripts - Install executables.
install-scripts:
	install -d $(DEST_SCRIPTS)
	install -m 0744 $(filter-out %/resticw, $(SRCS_SCRIPTS)) $(DEST_SCRIPTS)
	install -m 0755 usr/local/sbin/resticw $(DEST_SCRIPTS)

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

# target: uninstall - Uninstall ALL files from the install targets.
uninstall:
	@for file in $(INSTALLED_FILES); do \
			echo $(RM) $$file; \
			$(RM) $$file; \
	done
