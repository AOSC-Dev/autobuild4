#!/bin/bash -e
##proc/patch: Loads the build/ functions
##@copyright GPL-2.0+

if [ -f "$SRCDIR"/.patch ]; then
    return 0
fi

patch_root="$SRCDIR"/autobuild/patches/
if [ -f "$SRCDIR"/autobuild/patch ]; then
    arch_loadfile_strict -2 patch
    touch "$SRCDIR"/.patch
elif [ -f "$patch_root"/series ]; then
    series_file=
    arch_findfile -2 patches/series series_file
    abinfo "Applying patches using the listing from ${series_file} ..."
    ab_read_list "${series_file}" patches
    # patches variable is set inside the native function
    # shellcheck disable=SC2154
    ab_apply_patches "${patches[@]/#/autobuild/patches/}"
    touch "$SRCDIR"/.patch
elif [ -d "$patch_root" ]; then
    patch_dirs=("$patch_root")
    for dir in "$SRCDIR"/autobuild/patches/*/**/; do
        patch_dirs+=("$dir")
    done

    for src in "${patch_dirs[@]}"; do
        if [ ! -d "$src" ]; then
            continue
        fi
        subdir="${src#"$patch_root"}"
        dst="$SRCDIR"/"$subdir"
        
        abinfo "Applying patches from $src to $dst ...."
        if [ ! -d "$dst" ]; then
            aberr "Patch destination does no exist, aborting ..."
            exit 1
        fi
        if [ -f "$dst"/.patch ]; then
            continue
        fi

        cd "$dst"
        ab_apply_patches \
            "$src"/*.{patch,diff} \
            "$src"/*.{patch,diff}."${CROSS:-$ARCH}"
        ab_reverse_patches \
            "$src"/*.r{patch,diff} \
            "$src"/*.r{patch,diff}."${CROSS:-$ARCH}"
        touch .patch
    done
fi

cd "$SRCDIR"
