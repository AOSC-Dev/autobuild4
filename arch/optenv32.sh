#!/bin/bash
##arch/i386.sh: Build definitions for i386 (the subsystem that runs on amd64 cpus)
##@copyright GPL-2.0+
# OS Tree definitions
PREFIX="/opt/32"
BINDIR="/opt/32/bin"
LIBDIR="/opt/32/lib"
# PREFIX/etc and PREFIX/share will be replaced by symlinks to /etc and
# /usr/share.
BINFMTD="/usr/lib/binfmt.d"
INCLUDE="/opt/32/include"
LIBEXEC="/opt/32/libexec"
USRSRC="/opt/32/src"
SYDDIR="/opt/32/lib/systemd/system"
SYDSCR="/opt/32/lib/systemd/scripts"
TMPFILE="/usr/lib/tmpfiles.d"
JAVAHOME="/opt/32/lib/java"
QT4DIR="/opt/32/lib/qt4"
QT5DIR="/opt/32/lib/qt5"
QT4BIN="/opt/32/lib/qt4/bin"
QT5BIN="/opt/32/lib/qt5/bin"

# optenv32 packages should be packaged as amd64.
export DPKG_ARCH="amd64"
export PATH="$BINDIR:$PATH"

# linux32 tricks the build system.
export ABCONFWRAPPER="linux32"

# Disable Spiral provides generation.
ABSPIRAL=0

CFLAGS_COMMON_ARCH=('-fomit-frame-pointer' '-march=x86-64' '-mtune=sandybridge' '-msse2' '-m32')

export PKG_CONFIG_DIR=/opt/32/lib/pkgconfig
unset LDFLAGS_COMMON_CROSS_BASE
