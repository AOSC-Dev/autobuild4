#!/bin/bash
##filter/optenv32_drop_shared_files.sh: Drop shared arch-independent files from optenv runtime packages.
##@copyright GPL-2.0+

# Paths to be removed from PKGDIR.
OPTENV_SHARED_PATHS=("$PREFIX/etc" "$PREFIX/share" "$PREFIX/var")
filter_optenv_drop_shared_files() {
	if [[ "$ABHOST" = optenv* ]] ; then
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
