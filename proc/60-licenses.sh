#!/bin/bash
##proc/licenses.sh: SPDX-compatible license processing.
##@copyright GPL-2.0+
# _license_atom: _license [ " WITH " _exception ]
# TODO: Multiple exceptions, Unknown exceptions

mkdir -p "$PKGDIR/usr/share/doc/$PKGNAME"
find "$SRCDIR" -maxdepth 1 '(' -name 'COPYING*' -or -name 'LICENSE*' -or -name 'LICENCE*' ')' \
    -exec cp -L -r -v --no-preserve=mode '{}' "$PKGDIR/usr/share/doc/$PKGNAME" ';'

[ -n "$(ls -A "$PKGDIR/usr/share/doc/$PKGNAME")" ] ||
	abwarn "This package does not contain a COPYING or LICENCE file!"
