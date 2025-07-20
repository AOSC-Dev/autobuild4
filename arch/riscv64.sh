#!/bin/bash
##arch/riscv64.sh: Build definitions for riscv64.
##@copyright GPL-2.0+

# `-mno-omit-leaf-frame-pointer' is only available on GCC >= 14.
if ! bool "$USECLANG" && [ "$(echo __GNUC__ | $CC -E -xc - | tail -n 1)" -ge 14 ]; then
	CFLAGS_COMMON_ARCH=('-mno-omit-leaf-frame-pointer')
fi
LDFLAGS_COMMON_CROSS=('-Wl,-rpath -Wl,/usr/lib -Wl,-rpath-link' '-Wl,/var/ab/cross-root/riscv64/usr/lib' '-L/var/ab/cross-root/riscv64/usr/lib')
# FIXME: Since Rustc 1.88 (built against LLVM 20), RISC-V executables
# would fail to link due to missing -latomic symbols.
#
# This may be an upstream issue.
RUSTFLAGS_COMMON_ARCH=('-Clink-arg=-mabi=lp64d' '-Clink-arg=-latomic')
RUSTFLAGS_COMMON_ARCH_LTO=("${RUSTFLAGS_COMMON_ARCH[@]}" '-Clink-arg=-Wl,-mllvm=-mattr=+d' '-Clink-arg=-latomic')
