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
	-DSYSCONF_INSTALL_DIR="$SYSCONF"
	-DCMAKE_INSTALL_SBINDIR="$BINDIR"
	-DCMAKE_SKIP_INSTALL_RPATH=ON
	-DCMAKE_VERBOSE_MAKEFILE=ON
)


MESON_DEF=("--prefix=$PREFIX" "--sbindir=$BINDIR" "--buildtype=debugoptimized")
WAF_DEF=("--prefix=$PREFIX" "--configdir=$SYSCONF" "--libdir=$LIBDIR")
QTPROJ_DEF=("PREFIX=$PREFIX" "LIBDIR=$LIBDIR" "CONFIG+=force_debug_info")
MAKE_INSTALL_DEF=(
	"PREFIX=$PREFIX" "BINDIR=$BINDIR" "SBINDIR=$BINDIR" "LIBDIR=$LIBDIR"
	"INCDIR=$INCLUDE" "MANDIR=$MANDIR" "prefix=$PREFIX" "bindir=$BINDIR"
	"sbindir=$BINDIR" "libdir=$LIBDIR" "incdir=$INCLUDE" "mandir=$MANDIR"
)

