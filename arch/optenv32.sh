#!/bin/bash
##arch/i386.sh: Build definitions for i386 (the subsystem that runs on amd64 cpus)
##@copyright GPL-2.0+
# OS Tree definitions
PREFIX="/opt/32"
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"

# PREFIX/etc and PREFIX/share will be replaced by symlinks to /etc, /usr/share,
# and /var, respectively.
PREFIX="$PREFIX"
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"
SYSCONF="$PREFIX/etc"
CONFD="$PREFIX/etc/conf.d"
ETCDEF="$PREFIX/etc/default"
LDSOCONF="$PREFIX/etc/ld.so.conf.d"
FCCONF="$PREFIX/etc/fonts"
LOGROT="$PREFIX/etc/logrotate.d"
CROND="$PREFIX/etc/cron.d"
SKELDIR="$PREFIX/etc/skel"
BINFMTD="$PREFIX/lib/binfmt.d"
X11CONF="$PREFIX/etc/X11/xorg.conf.d"
STATDIR="$PREFIX/var"
INCLUDE="$PREFIX/include"
BOOTDIR="$PREFIX/boot"
LIBEXEC="$PREFIX/libexec"
MANDIR="$PREFIX/share/man"
FDOAPP="$PREFIX/share/applications"
FDOICO="$PREFIX/share/icons"
FONTDIR="$PREFIX/share/fonts"
USRSRC="$PREFIX/src"
VARLIB="$PREFIX/var/lib"
RUNDIR="$PREFIX/run"
DOCDIR="$PREFIX/share/doc"
LICDIR="$PREFIX/share/doc/licenses"
SYDDIR="$PREFIX/lib/systemd/system"
SYDSCR="$PREFIX/lib/systemd/scripts"
TMPFILE="$PREFIX/lib/tmpfiles.d"
PAMDIR="$PREFIX/etc/pam.d"
JAVAMOD="$PREFIX/share/java"
JAVAHOME="$PREFIX/lib/java"
GTKDOC="$PREFIX/share/gtk-doc"
GSCHEMAS="$PREFIX/share/glib-2.0/schemas"
THEMES="$PREFIX/share/themes"
BASHCOMP="$PREFIX/share/bash-completion"
ZSHCOMP="$PREFIX/share/zsh-completion"
PROFILED="$PREFIX/etc/profile.d"
LOCALES="$PREFIX/share/locales"
VIMDIR="$PREFIX/share/vim"
QT4DIR="$PREFIX/lib/qt4"
QT5DIR="$PREFIX/lib/qt5"
QT4BIN="$PREFIX/lib/qt4/bin"
QT5BIN="$PREFIX/lib/qt5/bin"

# optenv32 packages should be packaged as amd64.
export DPKG_ARCH="amd64"
export PATH="$BINDIR:$PATH"

# linux32 tricks the build system.
export ABCONFWRAPPER="linux32"

# Disable Spiral provides generation.
ABSPIRAL=0

CFLAGS_COMMON_ARCH=('-fomit-frame-pointer' '-march=x86-64' '-mtune=znver4' '-msse2' '-m32')
RUSTFLAGS_COMMON_ARCH=('-Clinker=/opt/32/bin/clang' '-Ctarget-cpu=x86-64')
ab_remove_args RUSTFLAGS_COMMON_OPTI_LTO '-Clinker=clang'

export PKG_CONFIG_PATH="/opt/32/lib/pkgconfig:/opt/32/share/pkgconfig"
unset LDFLAGS_COMMON_CROSS_BASE
