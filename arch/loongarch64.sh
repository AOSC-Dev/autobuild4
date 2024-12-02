#!/bin/bash
##arch/loongarch64.sh: Build definitions for LoongArch targets.
##@copyright GPL-2.0+

# la664 is only available on GCC >= 14 and Clang >= 19.
CFLAGS_COMMON_ARCH=('-mabi=lp64d' '-march=loongarch64' '-mlsx')
if ! bool "$USECLANG" && [ "$(echo __GNUC__ | gcc -E -xc - | tail -n 1)" -ge 14 ]; then
	# Use `-mtune=la664' if we are on GCC >= 14.
	CFLAGS_COMMON_ARCH+=('-mtune=la664')
elif bool "$USECLANG" && [ "$(echo __clang_major__ | clang -E -x c - | tail -n 1)" -ge 19 ]; then
	# Use `-mtune=la664' if we are on Clang >= 19.
	CFLAGS_COMMON_ARCH+=('-mtune=la664')
else
	# Fallback to `-mtune=la464' if we are not.
	CFLAGS_COMMON_ARCH+=('-mtune=la464')
fi

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=generic-la64' '-Ctarget-feature=+lsx,+d' '-Clink-arg=-mabi=lp64d')
