#!/bin/bash
##filter/infocompress.sh: Compresses Texinfo pages
##@copyright GPL-2.0+
filter_infocompress() {
	((ABINFOCOMPRESS)) || return
	local __infocomp_todo=()

	if [ -d "$PKGDIR"/usr/share/info ]; then
		for i in "$PKGDIR"/usr/share/info/*.info; do
			if [[ -L $i ]]; then
				local __infocomp_lnk
				__infocomp_lnk="$(readlink -f "$i")"
				rm "$i"
				ln -sf "$__infocomp_lnk".xz "$i"
			elif [[ -f $i ]]; then
				__infocomp_todo+=("$i")
			else
				abwarn "abinfocomp WTF for ${i#"$PKGDIR"}"
			fi
		done

		if ((${#__infocomp_todo})); then
			abinfo "Compressing Texinfo page ${__infocomp_todo[*]} ..."
			xz --lzma2=preset=6e,pb=0 -- "${__infocomp_todo[@]}"
		fi
	fi

	unset __infocomp_todo __infocomp_lnk
}

ab_register_filter infocompress
