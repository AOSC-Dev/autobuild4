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
        if [ ! -d "$dir" ]; then
            continue
        fi
        patch_dirs+=("$dir")
    done

    for src in "${patch_dirs[@]}"; do
        subdir="${src#"$patch_root"}"
        dst="$SRCDIR"/"$subdir"
        stage2_suffix=""

        abinfo "Applying patches from $src to $dst ...."
        if [ ! -d "$dst" ]; then
            abdie "Patch destination does no exist, aborting ..."
        fi
        if [ -f "$dst"/.patch ]; then
            continue
        fi

        cd "$dst"
        if bool "$ABSTAGE2"; then
            stage2_suffix=".stage2"
        fi
        ab_apply_patches \
            "$src"/*.{patch,diff}"${stage2_suffix}" \
            "$src"/*.{patch,diff}"${stage2_suffix}"."${CROSS:-$ARCH}"
        ab_reverse_patches \
            "$src"/*.r{patch,diff}"${stage2_suffix}" \
            "$src"/*.r{patch,diff}"${stage2_suffix}"."${CROSS:-$ARCH}"
        for archgroup in "${ABHOST_GROUP[@]}"; do
            ab_apply_patches \
                "$src"/*.{patch,diff}"${stage2_suffix}"."${archgroup}"
            ab_reverse_patches \
                "$src"/*.r{patch,diff}"${stage2_suffix}"."${archgroup}"
        done
        touch .patch
    done
fi

cd "$SRCDIR"
