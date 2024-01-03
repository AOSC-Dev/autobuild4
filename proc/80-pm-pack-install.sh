#!/bin/bash
##proc/pack: packs the package.
##@copyright GPL-2.0+

AB_PACKAGES=()

for i in "${ABMPM[@]}"; do
	abinfo "Packing $i package(s) ..."
	source "$AB"/pm/"$i".sh || aberr "$i packing returned $?."
    pm_build_package
    if [[ -d "${SYMDIR}" ]] && [ "$(ls -A "$SYMDIR")" ]; then
        pm_build_debug_package
    elif bool "$ABSPLITDBG"; then
        abdie "ABSPLITDBG is set, but we can't find any symbol files."
    fi
    pm_install_all "${AB_PACKAGES[@]}"
done
