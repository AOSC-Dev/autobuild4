#!/bin/bash
##arch/mips64r6el.sh: Build definitions for mips64r6el.
##@copyright GPL-2.0+
CFLAGS_COMMON_ARCH=('-march=mips64r6' '-mcompact-branches=always' '-mmsa')
CFLAGS_GCC_ARCH=('-mtune=mips64r6')

# FIXME: -Cdebuginfo=0 enables rustc to build programs on mips64r6el,
# overriding all project configuration and build profile settings.
# Generating debuginfo crashes LLVM (as of 15.0.7).
#
# FIXME: --cfg=rustix_use_libc works around an issue where a crate named
# rustix contains MIPS64 R2 assembly, without being able to distinguish between
# R2 and R6 assemblies. Enabling this options instructs rustix to use the libc
# backend instead.
#
# FIXME: As of Rust 1.71.1, enabling MSA results in broken sha2 checksum
# calculation (breaks all Cargo operations). Disable this feature for now.
RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=mips64r6' '-Cdebuginfo=0' '-Ctarget-feature=-msa' '-Cllvm-args=--mips-compact-branches=always' '--cfg=rustix_use_libc' '-Clink-arg=-Wl,--relax')

# Override some RUSTFLAGS sure that the correct linker is used with NOLTO=1.
RUSTFLAGS_COMMON_ARCH_NOLTO=('-Clink-arg=-fuse-ld=bfd' '-Clink-arg=-Wl,-build-id=sha1')
