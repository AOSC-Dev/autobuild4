#!/bin/bash
##proc/pack: packs the package.
##@copyright GPL-2.0+

AB_PACKAGES=()

for i in "${ABMPM[@]}"; do
    abinfo "Packing $i package(s) ..."
    source "$AB"/pm/"$i".sh || aberr "$i packing returned $?."
    pm_build_package

    # Check if there is any file in SYMDIR.
    # If the directory is created and not empty, create PKGNAME-dbg regardless of ABSPLITDBG.
    if [[ -d "${SYMDIR}" ]] && \
       [ "$(ls -A "$SYMDIR")" ]; then
        pm_build_debug_package
    elif bool "$ABSPLITDBG"; then
        # A empty dir or dir with no regular files becomes a fatal error if ABSPLITDBG is set.
        abdie "ABSPLITDBG is set, but we can't find any symbol files in ${SYMDIR}"
    fi
    pm_install_all "${AB_PACKAGES[@]}"
done
