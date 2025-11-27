#!/bin/bash
##arch/riscv64.sh: Build definitions for riscv64.
##@copyright GPL-2.0+

# `-mno-omit-leaf-frame-pointer' is only available on GCC >= 14.
if ! bool "$USECLANG" && [ "$(echo __GNUC__ | $CC -E -xc - | tail -n 1)" -ge 14 ]; then
	CFLAGS_COMMON_ARCH=('-mno-omit-leaf-frame-pointer')
fi
# `-mno-fence-tso` is only available on GCC >= 15
if ! bool "$USECLANG" && [ "$(echo __GNUC__ | $CC -E -xc - | tail -n 1)" -ge 15 ]; then
	CFLAGS_COMMON_ARCH+=('-mno-fence-tso')
fi
LDFLAGS_CLANG_ARCH=('-fuse-ld=lld' '-Wl,-mllvm=-mattr=+rva20u64')
LDFLAGS_COMMON_CROSS=('-Wl,-rpath -Wl,/usr/lib -Wl,-rpath-link' '-Wl,/var/ab/cross-root/riscv64/usr/lib' '-L/var/ab/cross-root/riscv64/usr/lib')
RUSTFLAGS_COMMON_ARCH=("-Clink-arg=-mabi=lp64d")
RUSTFLAGS_COMMON_ARCH_LTO=("${RUSTFLAGS_COMMON_ARCH[@]}" '-Clink-arg=-Wl,-mllvm=-mattr=+rva20u64')
