#!/bin/bash-
##Autobuild default config file
##@copyright CC0

# Misc building flags
ABARCHIVE=abpm_aosc_archive	# Archive program
ABSHADOW=yes			# Shall shadow builds be performed by default?
NOLTO=no			# Enable LTO by default.
USECLANG=no			# Are we using clang?
NOSTATIC=yes			# Want those big fat static libraries?
ABCLEAN=yes			# Clean before build?
NOLIBTOOL=yes			# Hug pkg-config and CMake configurations?
ABCONFIGHACK=yes		# Use config.{sub,guess} replacement for newer architectures?
NOCARGOAUDIT=no			# Audit Cargo (Rust) dependencies?
NONPMAUDIT=no			# Audit NPM dependencies?
ABUSECMAKEBUILD=yes		# Use cmake build for cmake* ABTYPEs?
ABSPLITDBG=yes			# Automatically compile with -g and produce debug symbol package ($PKGNAME-dbg)?
ABBUILDDEPONLY=no		# Avoid installing runtime dependencies when building?
ABPATCHLAX=no			# Disallow fuzzy patching
ABSPIRAL=yes			# Enable spiral provides generation

# Strict Autotools option checking?
AUTOTOOLS_STRICT=yes

# Parallelism, the default value is an equation depending on the number of processors.
# $ABTHREADS will take any integer larger than 0.
ABTHREADS=$(( $(nproc) + 1))
ABMANCOMPRESS=1
ABINFOCOMPRESS=1
ABELFDEP=0	# Guess dependencies from ldd?
ABSTRIP=1	# Should ELF be stripped off debug and unneeded symbols?

# Use -O3 instead?
AB_FLAGS_O3=0

# Use -Os instead?
AB_FLAGS_OS=0

# PIC and PIE are enabled by GCC/LD specs.
AB_FLAGS_SSP=1
AB_FLAGS_SCP=1
AB_FLAGS_RRO=1
AB_FLAGS_NOW=1
AB_FLAGS_FTF=1

# Fallback for Clang which does not support specs.
AB_FLAGS_PIC=1
AB_FLAGS_PIE=1

# Hardening specs?
AB_FLAGS_SPECS=1

# Enable table-based thread cancellation.
AB_FLAGS_EXC=1

AB_SAN_ADD=0
AB_SAN_THR=0
AB_SAN_LEK=0

# Use BFD LD?
AB_LD_BFD=1

# Default testing flags
ABTESTS=""
ABTEST_AUTO_DETECT=yes
ABTEST_ABORT_BUILD=no
ABTEST_TESTEXEC=plain
ABTEST_AUTO_DETECT_STAGE=post-build
ABTESTTYPE_rust_STAGE=post-build
NOTEST=yes

# AUTOTOOLS related
RECONF=yes

##Packaging info
ABQA=yes
ABINSTALL="dpkg"

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
