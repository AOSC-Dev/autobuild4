#!/bin/bash
##sections.sh: Kick the bucket if the section looks bad
##@copyright GPL-2.0+

for i in PKGNAME PKGSEC PKGDES PKGVER; do
    if ! abisdefined "$i"; then
        aberr "QA(104): variable $i must be defined." | tee -a "$SRCDIR"/abqaerr.log
    fi
done

if ! grep -qF "$PKGSEC" "$AB/sets/section"; then
  aberr "QA (E104): $PKGSEC not in sets/section." | tee -a "$SRCDIR"/abqaerr.log
fi

if arch_findfile -2 build && abisdefined ABTYPE && [[ "$ABTYPE" != "self" ]]; then
  aberr "QA (E105): free-formed build script exist while using a template." | tee -a "$SRCDIR"/abqaerr.log
fi
