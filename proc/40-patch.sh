#!/bin/bash -e
##proc/patch: Loads the build/ functions
##@copyright GPL-2.0+

if [ -f "$SRCDIR"/.patch ]; then
    return 0
fi

if [ -f "$SRCDIR"/autobuild/patch ]; then
    arch_loadfile_strict -2 patch
    touch "$SRCDIR"/.patch
elif [ -f "$SRCDIR"/autobuild/patches/series ]; then
    series_file=
    arch_findfile -2 patches/series series_file
    abinfo "Applying patches using the listing from ${series_file} ..."
    ab_read_list "${series_file}" patches
    # patches variable is set inside the native function
    # shellcheck disable=SC2154
    ab_apply_patches "${patches[@]}"
    touch "$SRCDIR"/.patch
elif [ -d "$SRCDIR"/autobuild/patches ]; then
    ab_apply_patches \
        "$SRCDIR"/autobuild/patches/*.{patch,diff} \
        "$SRCDIR"/autobuild/patches/*.{patch,diff}."${CROSS:-$ARCH}"
    ab_reverse_patches \
        "$SRCDIR"/autobuild/patches/*.r{patch,diff} \
        "$SRCDIR"/autobuild/patches/*.r{patch,diff}."${CROSS:-$ARCH}"
    touch "$SRCDIR"/.patch
fi

cd "$SRCDIR"
