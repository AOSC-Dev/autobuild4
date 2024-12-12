#!/bin/bash
##arch/loongarch64.sh: Build definitions for LoongArch targets.
##@copyright GPL-2.0+

# Per "Software Development and Build Convention for LoongArch
# Architectures v0.2":
#
#   Desktop and server operating operating systems both need to support
#   CPU platforms with at least 128-bit vector units.
#
#   To support 128-bit vector instructions, the compilation toolchain
#   should use the -march=la64v1.0 compilation option when compiling
#   desktop and server operating systems.
#
#   ...
#
#   The desktop and server operating system compilation toolchain should
#   enable -mno-strict-align compilation option.
#
# Our default flags comply with the Convention.
#
# Ref: https://github.com/loongson/la-softdev-convention/blob/v0.2/la-softdev-convention.adoc
CFLAGS_COMMON_ARCH=('-mabi=lp64d' '-march=la64v1.0' '-mno-strict-align')
# la664 is only available on GCC >= 14 and Clang >= 19.
if ! bool "$USECLANG" && [ "$(echo __GNUC__ | $CC -E -xc - | tail -n 1)" -ge 14 ]; then
	# Use `-mtune=la664' if we are on GCC >= 14.
	CFLAGS_COMMON_ARCH+=('-mtune=la664')
elif bool "$USECLANG" && [ "$(echo __clang_major__ | $CC -E -x c - | tail -n 1)" -ge 19 ]; then
	# Use `-mtune=la664' if we are on Clang >= 19.
	CFLAGS_COMMON_ARCH+=('-mtune=la664')
else
	# Fallback to `-mtune=la464' if we are not.
	CFLAGS_COMMON_ARCH+=('-mtune=la464')
fi

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=generic-la64' '-Ctarget-feature=+lsx,+d' '-Clink-arg=-mabi=lp64d')
