#!/bin/bash
##arch/loongson3.sh: Build definitions for Loongson 3A/B 1000-4000+.
##@copyright GPL-2.0+
CFLAGS_GCC_ARCH=('-mabi=64' '-march=gs464' '-mtune=gs464e' '-mxgot')
CFLAGS_CLANG_ARCH=('-mabi=64' '-march=mips64r2')
RUSTFLAGS_COMMON_ARCH=('-Clink-arg=-Wl,-build-id=sha1')

# Override some RUSTFLAGS sure that the correct linker is used with NOLTO=1.
RUSTFLAGS_COMMON_ARCH_NOLTO=('-Clink-arg=-fuse-ld=bfd' '-Clink-arg=-Wl,-build-id=sha1')

# Override some LTO flags to avoid partition size errors during linkage.
CFLAGS_GCC_ARCH_LTO=("${CFLAGS_COMMON_ARCH_LTO[@]}" '-flto-partition=none')
LDFLAGS_GCC_ARCH_LTO=("${LDFLAGS_COMMON_ARCH_LTO[@]}" '-mxgot' '-flto-partition=none')

# Position-independent executable buildmode is not available on any mips architecture.
# Removing for loongson3 target.
GOFLAGS=${GOFLAGS/-buildmode=pie/}
