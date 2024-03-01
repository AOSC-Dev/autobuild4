#!/bin/bash
##filter/mancompress.sh: Compresses manpages and break symlinks and boom
##@copyright GPL-2.0+
filter_mancompress() {
	if bool "$ABMANCOMPRESS"; then
		local __mancomp_todo=()

		if [ -d "$PKGDIR"/usr/share/man ]; then
			for i in "$PKGDIR"/usr/share/man/**/*.*; do
				if [[ $i == *.gz || $i == *.bz2 || $i = *.zst || $i == *.xz ]]; then
					continue
				fi

				if [[ -L $i ]]; then
					local __mancomp_lnk
					local __mancomp_lnk_rel
					__mancomp_lnk="$(readlink -f "$i")"
					__mancomp_lnk_rel="$(realpath --relative-to=$PKGDIR $__mancomp_lnk)"
					rm "$i"
					ln -svf /"$__mancomp_lnk_rel".xz "$i"
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
	fi
}

ab_register_filter mancompress
