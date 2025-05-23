#!/bin/bash-
##Autobuild default config file
##@copyright CC0

# Misc building flags
ABARCHIVE=abpm_aosc_archive	# Archive program
ABSHADOW=yes			# Shall shadow builds be performed by default?
FATLTO=no           # Disable Fat LTO by default
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

AB_SKIP_MAINTSCRIPTS=()		# Names of the scriptlets to skip generating or installing
				# Each element is one of prerm, postrm, preinst, postinst
				# The corresponding script will not installed to DEBIAN/ of the final package
AB_SKIP_ALLMAINTSCRIPTS=no	# Set to yes to skip all four maintscripts

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

# Enable control flow integrity protection.
AB_FLAGS_CFP=1

AB_SAN_ADD=0
AB_SAN_THR=0
AB_SAN_LEK=0

# Use BFD LD?
AB_LD_BFD=1

# Build for HWCAPS subtargets?
AB_HWCAPS=0

# Whether to trick autotools into thinking that we are *REALLY* cross compiling?
# Set this to 1 in order to work around the issue that autotools trying to run
# compile tests built for unsupported ISA levels without proper hardware.
# This is rather a hack to prevent unsupported code from running, so keeping it
# disabled. This is also not needed if configure does not run any compiled test
# code.
AB_HWCAPS_CROSS=0

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
GO_PACKAGES=('.')

if bool "$ABSTAGE2"; then
	abwarn "Autobuild4 running in stage2 mode ..."
	NOCARGOAUDIT=yes
	NONPMAUDIT=yes
	ABSPLITDBG=no
fi
