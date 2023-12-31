#!/bin/bash
##permissions: Check for incorrect permissions.
##@copyright GPL-2.0+
FILES="$(find "$PKGDIR/usr/bin" -type f -not -executable -print 2>/dev/null || true)"
if [ -n "$FILES" ]; then
	aberr "QA (E324): non-executable file(s) found in /usr/bin:\n\n${FILES}\n" | \
		tee -a "$SRCDIR"/abqaerr.log
fi

# the following checks assumes the existence of /usr/lib
if [ ! -d "$PKGDIR/usr/lib" ]; then
	return 0
fi

FILES="$(find "$PKGDIR/usr/lib" -type f -name '*.so.*' -not -executable \
	-exec bash -c '[[ "`file -bL {}`" == *shared\ object* ]] && exit 0' \; \
	-print 2>/dev/null)"
if [ -n "$FILES" ]; then
	aberr "QA (E324): non-executable shared object(s) found in /usr/lib:\n\n${FILES}\n" | \
		tee -a "$SRCDIR"/abqaerr.log
fi

FILES="$(find "$PKGDIR/usr/lib" -type f -name '*.a' -executable -print 2>/dev/null)"
if [ -n "$FILES" ]; then
	aberr "QA (E324): executable static object(s) found in /usr/lib:\n\n${FILES}\n" | \
		tee -a "$SRCDIR"/abqaerr.log
fi

FILES="$(find "$PKGDIR/usr/lib" -type f -name '*.o' -executable -print 2>/dev/null)"
if [ -n "$FILES" ]; then
	aberr "QA (E324): executable binary object(s) found in /usr/lib:\n\n${FILES}\n" | \
		tee -a "$SRCDIR"/abqaerr.log
fi
