#!/bin/bash
##filter/elf.sh: ELF-related filters
##@copyright GPL-2.0+

# Executable and libraries can only exist in following directories in AOSC OS package
# ref: AOSC OS Package Styling Manual (https://wiki.aosc.io/developer/packaging/package-styling-manual/)
#      Filesystem Hierarchy Standard 3.0 (https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
BIN_DIRS=(
	opt/
	usr/bin/
	usr/lib/
	usr/libexec/
	usr/local/bin/
	usr/local/lib/
	usr/local/libexec/
)

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
	for p in "${BIN_DIRS[@]}"; do
		i="$PKGDIR"/"$p"
	    if [ -d "$i" ]; then
			_elf_path+=("$i")
        fi
	done

	abelf_copy_dbg_parallel "${_opts[@]}" "${_elf_path[@]}" "${SYMDIR}"
}

ab_register_filter elf
