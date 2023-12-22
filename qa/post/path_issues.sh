#!/bin/bash
##path_issues: Check for incorrectly installed paths.
##@copyright GPL-2.0+

for i in \
	bin sbin lib lib64 usr/sbin usr/lib64 \
	usr/local usr/man usr/doc usr/etc usr/var; do
	if [ -e "$PKGDIR"/${i} ]; then
		aberr "QA (E321): Found known bad path in package:\n\n${i}\n" | \
			tee -a "$SRCDIR"/abqaerr.log
		exit 1
	fi
done

ACCEPTABLE=(
boot
dev
efi
etc
home
media
mnt
opt
proc
root
run
snap
snapd
srv
sys
tmp
usr
var
)

ACCEPTABLE2=(
usr/bin
usr/include
usr/gnemul
usr/lib
usr/libexec
usr/local
usr/share
usr/src
)

ACCEPTABLE3=(
usr/local/bin
usr/local/include
usr/local/lib
usr/local/libexec
usr/local/share
usr/local/src
)

abqa_build_find_expr() {
	local -n _patterns="$1"
	local -n _expr="$2"
    for pattern in "${_patterns[@]}"; do
		_expr+=('!' '-name' "${pattern}" '-and')
	done
	_expr[-1]='-print'
}

EXPR1=()
EXPR2=()
EXPR3=()
abqa_build_find_expr ACCEPTABLE EXPR1
abqa_build_find_expr ACCEPTABLE2 EXPR2
abqa_build_find_expr ACCEPTABLE3 EXPR3
PATHS="$(find "$PKGDIR" -maxdepth 1 "${EXPR1[@]}" -type d 2>/dev/null)"
PATHS2="$(find "$PKGDIR"/usr -mindepth 1 -maxdepth 1 "${EXPR2[@]}" -type d 2>/dev/null)"
PATHS3="$(find "$PKGDIR"/usr/local -mindepth 1 -maxdepth 1 "${EXPR3[@]}" -type d 2>/dev/null)"

if [ -n "$PATHS" ]; then
	aberr "QA (E321): found unexpected path(s) in package:\n\n$PATHS\n"
	exit 1
fi
if [ -n "$PATHS2" ]; then
	aberr "QA (E321): found unexpected path(s) in package:\n\n$PATHS2\n"
	exit 1
fi
if [ -n "$PATHS3" ]; then
	aberr "QA (E321): found unexpected path(s) in package:\n\n$PATHS3\n"
	exit 1
fi


for i in "$PKGDIR"/{dev,home,proc,sys,tmp}; do
	if [ -e "$i" ]; then
		abwarn "QA (E321): found pseudo filesystem, template, or temporary directory(s) in package (building aosc-aaa?):\n\n${i}\n"
		exit 1
	fi
done
