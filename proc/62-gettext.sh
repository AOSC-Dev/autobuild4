#!/bin/bash
##62-gettext.sh: Generate and install Gettext files automatically

bool $ABSTAGE2 && return 0

if ! [ -d "$SRCDIR"/autobuild/po ] ; then
	return 0
fi

abinfo "Generating binary Gettext message catalogs ..."
for lang in "${GETTEXT_LINGUAS[@]}" ; do
	msgfmt -vo "$SRCDIR"/autobuild/po/"$lang".mo \
		"$SRCDIR"/autobuild/po/"$lang.po"
done

abinfo "Installing generated Gettext message catalogs ..."
for lang in "${GETTEXT_LINGUAS[@]}" ; do
	install -Dvm644 "$SRCDIR"/autobuild/po/"$lang".mo \
		"$PKGDIR"/usr/share/locale/"$lang"/LC_MESSAGES/"$GETTEXT_DOMAIN".mo
done
