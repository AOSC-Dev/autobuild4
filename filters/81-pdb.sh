#!/bin/bash
##filter/pdb.sh: Move or delete Program Database file
##@copyright GPL-2.0+

filter_pdb() {
	for p in ${BIN_DIRS[@]}; do
        i="$PKGDIR"/"$p"
	    if [ -d "$i" ]; then
            for f in `find "$i" -type f -name "*.pdb"`; do
                if bool "$ABSPLITDBG"; then
                    path="${f#"$PKGDIR"}"
                    abinfo "Saving Program Database file $f ..."
                    mkdir -p `dirname "$SYMDIR"/"$path"`
                    mv "$f" "$SYMDIR"/"$path"
                elif bool "$ABSTRIP"; then
                    abinfo "Dropping Program Database file $f ..."
                    rm "$f"
                fi
            done
        fi
	done
}

ab_register_filter pdb
