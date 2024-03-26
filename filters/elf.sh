#!/bin/bash
##filter/elf.sh: ELF-related filters
##@copyright GPL-2.0+

filter_elf() {
	local _opts=()
	if ! bool "$ABSTRIP"; then
		abinfo 'Not stripping ELF binaries as requested.'
	    _opts+=('-r')
	elif ! bool "$ABSPLITDBG"; then
	    abinfo 'Not splitting ELF binaries as requested.'
		_opts+=('-x')
	fi

	local _elf_path=()
	for i in "$PKGDIR"/{opt/*/*/,opt/*/,usr/,}{lib{,64,exec},{s,}bin}/; do
	    if [ -d "$i" ]; then
			_elf_path+=("$i")
        fi
	done

	abelf_copy_dbg_parallel "${_opts[@]}" "${_elf_path[@]}" "${SYMDIR}"
}

ab_register_filter elf
