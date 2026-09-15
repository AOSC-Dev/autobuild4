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
	# FIXME: A large number of projects would still build with CMake >= 4.0
	# with -DCMAKE_POLICY_VERSION_MINIMUM=3.5 specified. Most projects
	# simply never updated their CMake policy version requirement, throwing
	# this error during build time:
	#
	# CMake Error at CMakeLists.txt:2 (cmake_minimum_required):
	# Compatibility with CMake < 3.5 has been removed from CMake.
	#
	#   Update the VERSION argument <min> value.  Or, use the <min>...<max> syntax
	#   to tell CMake that the project requires at least <min> but has been updated
	#   to work with policies introduced by <max> or earlier.
	#
	#   Or, add -DCMAKE_POLICY_VERSION_MINIMUM=3.5 to try configuring anyway.
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5
)
AUTOSETUP_DEF=(
	--prefix="$PREFIX"
)


MESON_DEF=(
	"--prefix=$PREFIX" "--sbindir=$BINDIR"
	"--buildtype=debugoptimized" "-Dwrap_mode=nodownload"
)
WAF_DEF=("--prefix=$PREFIX" "--configdir=$SYSCONF" "--libdir=$LIBDIR")
QTPROJ_DEF=("PREFIX=$PREFIX" "LIBDIR=$LIBDIR" "CONFIG+=force_debug_info")
MAKE_INSTALL_DEF=(
	"PREFIX=$PREFIX" "BINDIR=$BINDIR" "SBINDIR=$BINDIR" "LIBDIR=$LIBDIR"
	"INCDIR=$INCLUDE" "MANDIR=$MANDIR" "prefix=$PREFIX" "bindir=$BINDIR"
	"sbindir=$BINDIR" "libdir=$LIBDIR" "incdir=$INCLUDE" "mandir=$MANDIR"
)

# Python defaults
NOPYTHON2=1
NOPYTHON3=0
