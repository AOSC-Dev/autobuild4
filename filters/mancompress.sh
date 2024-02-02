#!/bin/bash
##filter/mancompress.sh: Compresses manpages and break symlinks and boom
##@copyright GPL-2.0+
filter_mancompress() {
	((ABMANCOMPRESS)) || return
	local __mancomp_todo=()

	if [ -d "$PKGDIR"/usr/share/man ]; then
		for i in "$PKGDIR"/usr/share/man/**/*.*; do
			if [[ $i == *.gz || $i == *.bz2 || $i = *.zst || $i == *.xz ]]; then
				continue
			fi

			if [[ -L $i ]]; then
				local __mancomp_lnk
				__mancomp_lnk="$(readlink -f "$i")"
				rm "$i"
				ln -sf "$__mancomp_lnk".xz "$i"
			elif [[ -f $i ]]; then
				__mancomp_todo+=("$i")
			else
				abwarn "abmancomp WTF for ${i#"$PKGDIR"}"
			fi
		done

		if ((${#__mancomp_todo})); then
			abinfo "Compressing man page ${__mancomp_todo[*]} ..."
			xz --lzma2=preset=6e,pb=0 --force -- "${__mancomp_todo[@]}"
		fi
	fi

	unset __mancomp_todo __mancomp_lnk
}

ab_register_filter mancompress
