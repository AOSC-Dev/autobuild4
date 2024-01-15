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

CFLAGS_COMMON_ARCH=('-fomit-frame-pointer' '-march=pentium4' '-mtune=core2' '-msse' '-msse2' '-msse3')

export PKG_CONFIG_DIR=/opt/32/lib/pkgconfig
unset LDFLAGS_COMMON_CROSS_BASE
