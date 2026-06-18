#!/bin/bash
##filter/retro_drop_docs.sh: Drop /usr/share/{,gtk-}doc for Retro architectures.
##@copyright GPL-2.0+

# Drop any manpage that is not in Section 1 (User Commands), Section 5
# (File Formants), Section 6 (Games), Section 7 (conventions) and
# Section 8 (Administrative Commands).
_retro_drop_manpages() {
	local tgt="$1"
	if [ -z "$tgt" ] ; then
		tgt="$PKGDIR/usr/share/man"
	fi
	for dir in `find "$tgt" -mindepth 1 -maxdepth 1 -type d -printf '%P\n'` ; do
		# Check the translations first: /usr/share/man/$LOCALE
		if [ "${dir##man}" == "$dir" ] ; then
			_retro_drop_manpages "$tgt"/"$dir"
			continue
		fi
		if [ "${dir%%[15678]}" == "$dir" ] ; then
			for manfile in `find "$tgt"/"$dir" -mindepth 1 -not -type d` ; do
				abinfo "Removing $manfile ..."
				rm "$manfile"
			done
			abinfo "Removing $tgt/$dir ..."
			rm -rv "$tgt/$dir"
		fi
	done
}

filter_retro_drop_docs() {
	if ab_match_archgroup retro; then
		if [ -d "$PKGDIR"/usr/share/doc ]; then
			abinfo "Dropping documentation ..."
			rm -r "$PKGDIR"/usr/share/doc
		fi

		# GTK-Doc stores Python modules in /usr/share/gtk-doc,
		# dropping this directory will render its tools unusable.
		if [[ "$PKGNAME" != "gtk-doc" && \
			-d "$PKGDIR"/usr/share/gtk-doc ]]; then
			abinfo "Dropping gtk-doc ..."
			rm -r "$PKGDIR"/usr/share/gtk-doc
		fi

		# Drop any unnecessary manual pages.
		if [ -d "$PKGDIR"/usr/share/man ] ; then
			_retro_drop_manpages "$PKGDIR"/usr/share/man
		fi
	else
		abinfo "Non-Retro architectures detected, skipping retro_drop_docs ..."
	fi
}

ab_register_filter retro_drop_docs
