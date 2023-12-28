#!/bin/bash
##proc/build_do: So we build it now
##@copyright GPL-2.0+

arch_loadfile_strict -2 prepare

cd "$SRCDIR"

if ! ab_typecheck -f "build_${ABTYPE}_audit"; then
    "build_${ABTYPE}_audit" || abdie "Audit failed: $?."
fi

"build_${ABTYPE}_configure" || abdie "Configure failed: $?."
"build_${ABTYPE}_build" || abdie "Build failed: $?."
"build_${ABTYPE}_install" || abdie "Install failed: $?."

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

[ -d "$PKGDIR" ] || abdie "50-build: Suspecting build failure due to missing PKGDIR."

arch_loadfile_strict -2 beyond

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

__overrides="$(arch_findfile -2 overrides)"
if [ -d "${__overrides}" ]; then
    abinfo "Deploying files in overrides ..."
	cp -arvT "${__overrides}"/ "$PKGDIR/" || \
		abdie "Failed to deploy files in overrides: $?."
fi

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

unalias BUILD_{START,READY,FINAL}
unset __overrides
