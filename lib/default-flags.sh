#!/bin/bash-
##Autobuild default config file
##@copyright CC0

##OS basic configuration flags
AUTOTOOLS_DEF=(
	--prefix="$PREFIX"
	--sysconfdir="$SYSCONF"
	--localstatedir="$STATDIR"
	--libdir="$LIBDIR"
	--bindir="$BINDIR"
	--sbindir="$BINDIR"
	--mandir="$MANDIR"
)
CMAKE_DEF=(
	-DCMAKE_INSTALL_PREFIX="$PREFIX"
	-DCMAKE_BUILD_TYPE=RelWithDebInfo
	-DCMAKE_INSTALL_LIBDIR=lib
	-DLIB_INSTALL_DIR=lib
	-DSYSCONF_INSTALL_DIR="$SYSCONF"
	-DCMAKE_INSTALL_SBINDIR="$BINDIR"
	-DCMAKE_SKIP_RPATH=ON
	-DCMAKE_VERBOSE_MAKEFILE=ON
)


MESON_DEF=("--prefix=$PREFIX" "--sbindir=$BINDIR")
WAF_DEF=("--prefix=$PREFIX" "--configdir=$SYSCONF" "--libdir=$LIBDIR")
QTPROJ_DEF=("PREFIX=$PREFIX" "LIBDIR=$LIBDIR" "CONFIG+=force_debug_info")
MAKE_INSTALL_DEF=(
	"PREFIX=$PREFIX" "BINDIR=$BINDIR" "SBINDIR=$BINDIR" "LIBDIR=$LIBDIR"
	"INCDIR=$INCLUDE" "MANDIR=$MANDIR" "prefix=$PREFIX" "bindir=$BINDIR"
	"sbindir=$BINDIR" "libdir=$LIBDIR" "incdir=$INCLUDE" "mandir=$MANDIR"
)

# Golang default build flags | Adapted from Arch Linux's Go package guildline.
__GOFLAGS=(
	'-mod=readonly'  # Ensure module files are not updated during building process.
	'-trimpath'      # Required for reproducible build.
	'-modcacherw'    # Ensures that go modules creates a write-able path.
	'-buildmode=pie'  # Hardening binary.
)
GOFLAGS="${__GOFLAGS[*]}"
GO_LDFLAGS=()
unset -f __GOFLAGS

if [ -f /etc/autobuild/ab3cfg.sh ]; then
    abwarn "Using configurations from Autobuild3"
	. /etc/autobuild/ab3cfg.sh
else
	. /etc/autobuild/ab4cfg.sh
fi

if bool "$ABSTAGE2"; then
	abwarn "Autobuild4 running in stage2 mode ..."
	NOCARGOAUDIT=yes
	NONPMAUDIT=yes
	ABSPLITDBG=no
fi
