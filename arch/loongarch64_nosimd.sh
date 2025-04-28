#!/bin/bash
##arch/loongarch64.sh: Build definitions for LoongArch targets.
##@copyright GPL-2.0+

# Unlike what is specified in "Software Development and Build Convention
# for LoongArch Architectures v0.2", this port is intended for SIMD-less
# platforms such as the Loongson 2K0300.
#
# Ref: https://github.com/loongson/la-softdev-convention/blob/v0.2/la-softdev-convention.adoc
CFLAGS_COMMON_ARCH=('-mabi=lp64d' '-mstrict-align' '-march=loongarch64' '-mtune=loongarch64')
# -msimd=none is not supported by Clang < 19 or GCC < 14.
if ! bool "$USECLANG" && \
    [ "$(echo __GNUC__ | $CC -E -xc - | tail -n 1)" -le 14 ]; then
	CFLAGS_COMMON_ARCH+=('-mno-lsx' '-mno-lasx')
elif bool "$USECLANG" && \
    [ "$(echo __clang_major__ | $CC -E -x c - | tail -n 1)" -le 19 ]; then
	CFLAGS_COMMON_ARCH+=('-mno-lsx' '-mno-lasx')
else
	CFLAGS_COMMON_ARCH+=('-msimd=none')
fi
# Current LLVM/Clang/rustc implementation assumes LSX for all LoongArch64 targets.
#
#   - https://github.com/llvm/llvm-project/blob/98b895da30c03b7061b8740d91c0e7998e69d091/clang/lib/Driver/ToolChains/Arch/LoongArch.cpp#L133
#   - https://github.com/rust-lang/rust/blob/a932eb36f8adf6c8cdfc450f063943da3112d621/compiler/rustc_target/src/spec/targets/loongarch64_unknown_linux_gnu.rs#L18
#   - https://github.com/llvm/llvm-project/blob/98b895da30c03b7061b8740d91c0e7998e69d091/clang/lib/Driver/ToolChains/Arch/LoongArch.cpp#L133
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=generic-la64' '-Ctarget-feature=-lsx,+d' '-Clink-arg=-mabi=lp64d')
