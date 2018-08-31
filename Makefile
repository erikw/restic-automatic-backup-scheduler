# Not file targets.
.PHONY: help install install-scripts install-conf install-exclude install-systemd

### Macros ###
SRCS_SCRIPTS	= $(filter-out %cron_mail, $(wildcard usr/local/sbin/*))
SRCS_CONF	= $(wildcard etc/restic/*)
SRCS_EXCLUDE	= .backup_exclude
SRCS_SYSTEMD	= $(wildcard etc/systemd/system/*)

# Just set PREFIX in envionment, like
# $ PREFIX=/tmp/test make
DEST_SCRIPTS	= $(PREFIX)/usr/local/sbin
DEST_CONF	= $(PREFIX)/etc/restic
DEST_EXCLUDE	= $(PREFIX)/
DEST_SYSTEMD	= $(PREFIX)/etc/systemd/system


### Targets ###
# target: all - Default target.
all: install

# target: help - Display all targets.
help:
	@egrep "#\starget:" [Mm]akefile  | sed 's/\s-\s/\t\t\t/' | cut -d " " -f3- | sort -d

# target: install - Install all files
install: install-scripts install-conf install-exclude install-systemd


# target: install-scripts - Install executables.
install-scripts:
	install -d $(DEST_SCRIPTS)
	install -m 744 $(SRCS_SCRIPTS) $(DEST_SCRIPTS)

# target: install-conf - Install restic configuration files.
install-conf:
	install -d $(DEST_CONF) -m 700
	install $(SRCS_CONF) $(DEST_CONF)

# target: install-exclude - Install backup exclude file.
install-exclude:
	install $(SRCS_EXCLUDE) $(DEST_EXCLUDE)

# target: install-systemd - Install systemd timer and service files
install-systemd:
	install -d $(DEST_SYSTEMD)
	install $(SRCS_SYSTEMD) $(DEST_SYSTEMD)
