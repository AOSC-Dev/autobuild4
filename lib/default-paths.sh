#!/bin/bash-
##Autobuild default config file - OS Tree definition
##@copyright CC0

# Environmental Settings
# Avoid setting TMPDIR as tmpfs mount points.
TMPDIR="$SRCDIR"

##OS Directory Tree
# Built-in variables for AOSC OS directory tree.
# Will be updated. Therefore not part of conffiles.
#
PREFIX="/usr"
BINDIR="/usr/bin"
LIBDIR="/usr/lib"
SYSCONF="/etc"
CONFD="/etc/conf.d"
ETCDEF="/etc/default"
LDSOCONF="/etc/ld.so.conf.d"
FCCONF="/etc/fonts"
LOGROT="/etc/logrotate.d"
CROND="/etc/cron.d"
SKELDIR="/etc/skel"
BINFMTD="/usr/lib/binfmt.d"
X11CONF="/etc/X11/xorg.conf.d"
STATDIR="/var"
INCLUDE="/usr/include"
BOOTDIR="/boot"
LIBEXEC="/usr/libexec"
MANDIR="/usr/share/man"
FDOAPP="/usr/share/applications"
FDOICO="/usr/share/icons"
FONTDIR="/usr/share/fonts"
USRSRC="/usr/src"
VARLIB="/var/lib"
RUNDIR="/run"
DOCDIR="/usr/share/doc"
LICDIR="/usr/share/doc/licenses"
SYDDIR="/usr/lib/systemd/system"
SYDSCR="/usr/lib/systemd/scripts"
TMPFILE="/usr/lib/tmpfiles.d"
PAMDIR="/etc/pam.d"
JAVAMOD="/usr/share/java"
JAVAHOME="/usr/lib/java"
GTKDOC="/usr/share/gtk-doc"
GSCHEMAS="/usr/share/glib-2.0/schemas"
THEMES="/usr/share/themes"
BASHCOMP="/usr/share/bash-completion"
ZSHCOMP="/usr/share/zsh-completion"
PROFILED="/etc/profile.d"
LOCALES="/usr/share/locales"
VIMDIR="/usr/share/vim"
QT4DIR="/usr/lib/qt4"
QT5DIR="/usr/lib/qt5"
QT4BIN="/usr/lib/qt4/bin"
QT5BIN="/usr/lib/qt5/bin"

# The above paths might be replaced under the following condition(s):
# - Building packages for optenv32
# - Building packages for optenvx64 (which might happen in the future).
