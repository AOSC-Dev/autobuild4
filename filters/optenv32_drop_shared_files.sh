#!/bin/bash
##filter/retro_drop_docs.sh: Drop /usr/share/{,gtk-}doc for Retro architectures.
##@copyright GPL-2.0+

# Paths to be removed from PKGDIR.
OPTENV_SHARED_PATHS=("$PREFIX/etc" "$PREFIX/share" "$PREFIX/var" "/etc" "/share" "/var" "/usr")
filter_optenv_drop_shared_files() {
	if ab_match_archgroup optenv; then
		abinfo "optenv target detected, removing shared files from the package directory ..."
		for rmpath in ${OPTENV_SHARED_PATHS[@]} ; do
			if [ -d "$PKGDIR"/"$rmpath" ] ; then
				abinfo "Removing $rmpath from the package directory ..."
				# Probably way too verbose.
				rm -r "$PKGDIR"/"$rmpath"
			fi
		done
	else
		abinfo "Non-optenv target detected, skipping optenv_drop_shared_files ..."
	fi
}

ab_register_filter optenv_drop_shared_files
