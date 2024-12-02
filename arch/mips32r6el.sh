#!/bin/bash
##arch/mips32r6el.sh: Build definitions for mips32r6el.
##@copyright GPL-2.0+
CFLAGS_COMMON_ARCH=('-march=mips32r6' '-mcompact-branches=always')
CFLAGS_GCC_ARCH=('-mtune=mips32r6')

# FIXME: -Cdebuginfo=0 enables rustc to build programs on mips32r6el,
# overriding all project configuration and build profile settings.
# Generating debuginfo crashes LLVM (as of 15.0.7).
#
# FIXME: --cfg=rustix_use_libc works around an issue where a crate named
# rustix contains MIPS32 R2 assembly, without being able to distinguish between
# R2 and R6 assemblies. Enabling this options instructs rustix to use the libc
# backend instead.
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=mips32r6' '-Cdebuginfo=0' '-Cllvm-args=--mips-compact-branches=always' '--cfg=rustix_use_libc')

# Override some RUSTFLAGS sure that the correct linker is used with NOLTO=1.
RUSTFLAGS_COMMON_ARCH_NOLTO=('-Clink-arg=-fuse-ld=gold' '-Clink-arg=-Wl,-build-id=sha1')
