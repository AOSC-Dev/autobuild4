#!/bin/bash
##filter/elf.sh: ELF-related filters
##@copyright GPL-2.0+

filter_elf() {
	if ! bool "$ABSTRIP"; then
		abinfo 'Not stripping ELF binaries as requested.'
	    return 0;
    fi

	local _elf_path=()
	for i in "$PKGDIR"/{opt/*/*/,opt/*/,usr/,}{lib{,64,exec},{s,}bin}/; do
	    if [ -d "$i" ]; then
			_elf_path+=("$i")
        fi
	done
	
	abelf_copy_dbg_parallel "${_elf_path[@]}" "${SYMDIR}"
}

ab_register_filter elf
