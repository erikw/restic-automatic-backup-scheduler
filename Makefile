#### Notes ####################################################################
# This build process is done in three stages:
# 1. copy source files to the local build directory.
# 2. replace the string "$INSTALL_PREFIX" with the value of $PREFIX
# 3. copy files from the build directory to the target directory.
#
# Why this dance?
# * To fully support that a user can install this project to a custom path e.g.
#   $(PREFIX=/usr/local make install), we need to modify the files that refer
#   to other files on disk. We do this by having a placeholder
#   "$INSTALL_PREFIX"  that is substituted with the value of $PREFIX when
#   installed.
# * We don't want to modify the files that are controlled by git, thus let's
#   copy them to a build directory and then modify.

#### Non-file targets #########################################################
.PHONY: all help clean uninstall \
	install install-scripts install-conf install-systemd

#### Macros ###################################################################
NOW := $(shell date +%Y-%m-%d_%H:%M:%S)

# GNU install and macOS install have incompatible command line arguments.
GNU_INSTALL := $(shell install --version 2>/dev/null | \
			   grep -q GNU && echo true || echo false)
ifeq ($(GNU_INSTALL),true)
    BAK_SUFFIX = --suffix=.$(NOW).bak
else
    BAK_SUFFIX = -B .$(NOW).bak
endif

# Create parent directories of a file, if not existing.
# Reference: https://stackoverflow.com/a/25574592/265508
MKDIR_PARENTS=sh -c '\
	     dir=$$(dirname $$1); \
	     test -d $$dir || mkdir -p $$dir \
	     ' MKDIR_PARENTS


# Source directories.
DIR_SCRIPTS	= sbin
DIR_CONF	= etc/restic
DIR_SYSTEMD	= usr/lib/systemd/system

# Source files.
SRCS_SCRIPTS	= $(filter-out %cron_mail, $(wildcard $(DIR_SCRIPTS)/*))
# $(sort) remove duplicates that comes from running make install >1 times.
SRCS_CONF	= $(sort $(patsubst %.template, %, $(wildcard $(DIR_CONF)/*)))
SRCS_SYSTEMD	= $(wildcard $(DIR_SYSTEMD)/*)


# Local build directory. Sources will be copied here,
# modified and then installed from this directory.
BUILD_DIR := build
BUILD_DIR_SCRIPTS	= $(BUILD_DIR)/$(DIR_SCRIPTS)
BUILD_DIR_CONF		= $(BUILD_DIR)/$(DIR_CONF)
BUILD_DIR_SYSTEMD	= $(BUILD_DIR)/$(DIR_SYSTEMD)

# Sources copied to build directory.
BUILD_SRCS_SCRIPTS	= $(addprefix $(BUILD_DIR)/, $(SRCS_SCRIPTS))
BUILD_SRCS_CONF		= $(addprefix $(BUILD_DIR)/, $(SRCS_CONF))
BUILD_SRCS_SYSTEMD	= $(addprefix $(BUILD_DIR)/, $(SRCS_SYSTEMD))

# Destination directories
DEST_DIR_SCRIPTS	= $(PREFIX)/$(DIR_SCRIPTS)
DEST_DIR_CONF		= $(PREFIX)/$(DIR_CONF)
DEST_DIR_SYSTEMD	= $(PREFIX)/$(DIR_SYSTEMD)

# Destination files.
DEST_SCRIPTS	= $(addprefix $(PREFIX)/, $(SRCS_SCRIPTS))
DEST_CONF	= $(addprefix $(PREFIX)/, $(SRCS_CONF))
DEST_SYSTEMD	= $(addprefix $(PREFIX)/, $(SRCS_SYSTEMD))

INSTALLED_FILES = $(DEST_SCRIPTS) $(DEST_CONF) $(DEST_SYSTEMD)


#### Targets ##################################################################
# target: all - Default target.
all: install

# target: help - Display all targets.
help:
	@egrep "#\starget:" [Mm]akefile  | \
		sed 's/\s-\s/\t\t\t/' | cut -d " " -f3- | sort -d

# target: clean - Remove build files.
clean:
	$(RM) -r $(BUILD_DIR)

# target: uninstall - Uninstall ALL files from the install targets.
uninstall:
	@for file in $(INSTALLED_FILES); do \
			echo $(RM) $$file; \
			$(RM) $$file; \
	done

# To change the installation root path,
# set the PREFIX variable in your shell's environment, like:
# $ PREFIX=/usr/local make install
# $ PREFIX=/tmp/test make install
# target: install - Install all files
install: install-scripts install-conf install-systemd

# Install targets - add build sources to prereq as well,
# so that build dir is re-created if deleted (expected behaviour).
#
# target: install-scripts - Install executables.
install-scripts: $(DEST_SCRIPTS) $(BUILD_SRCS_CONF)
# target: install-conf - Install restic configuration files.
install-conf: $(DEST_CONF) $(BUILD_SRCS_CONF)
# target: install-systemd - Install systemd timer and service files.
install-systemd: $(DEST_SYSTEMD)  $(BUILD_SRCS_CONF)

# Copies sources to build directory & replace "$INSTALL_PREFIX"
$(BUILD_DIR)/% : %
	${MKDIR_PARENTS} $@
	cp $< $@
	sed -i.bak -e 's|$$INSTALL_PREFIX|$(PREFIX)|g' $@; rm $@.bak

# Install destination script files.
$(DEST_DIR_SCRIPTS)/%: $(BUILD_DIR_SCRIPTS)/%
	${MKDIR_PARENTS} $@
	install -m 0744 $< $@

# Install destination conf files. Additionally backup existing files.
$(DEST_DIR_CONF)/%: $(BUILD_DIR_CONF)/%
	${MKDIR_PARENTS} $@
	install -m 0600 -b $(BAK_SUFFIX) $< $@

# Install destination system files.
$(DEST_DIR_SYSTEMD)/%: $(BUILD_DIR_SYSTEMD)/%
	${MKDIR_PARENTS} $@
	install -m 0644 $< $@
