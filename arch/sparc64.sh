#!/bin/bash
##arch/sparc64.sh: Build definitions for sparc64.
##@copyright GPL-2.0+

# Retro: Overriding mainline definitions, and take more interest in reducing code size.
CFLAGS_COMMON_ARCH=('-O2' '-fno-tree-ch' '-ffunction-sections' '-fdata-sections')
LDFLAGS_COMMON_ARCH=('-Wl,--gc-sections')

CFLAGS_COMMON_ARCH=('-march=v9' '-mv8plus' '-mvis' '-m64' '-mcmodel=medany')

RUSTFLAGS_COMMON_ARCH=('-Ctarget-cpu=v9' '-Ctarget-feature=+vis' '-Ccode-model=medium')
