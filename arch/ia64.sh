#!/bin/bash
# arch/ia64.sh: Arch definition for IA-64

# NOTE: Tuning baseline is set to Itanium 2 family of chips, such as
# McKinley, Madison, Montecito and Tukwila.
# Due to lack of public interest, hardware availability, and its
# quirky and slowness nature, Merced family of chips are considered
# not well supported and quirky. GCC deprecated -mtune=itanium1 in
# 2009 at bbb6eae87edb29b26e7c545645fac3d76a4605d8.
CFLAGS_COMMON_ARCH=('-O2' '-mtune=itanium2')

# NOTE: -O3 causes ICEs.
AB_FLAGS_O3=0
# NOTE: Despite the stack growing downwards, they hardcoded
# FRAME_GROWS_DOWNWARD to 0, so no stack protector support.
AB_FLAGS_SSP=0
