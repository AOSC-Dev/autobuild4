#!/bin/bash
# Deploy override files after running the filters.

cd "$SRCDIR" || abdie "Unable to cd $SRCDIR: $?."

__overrides=
if arch_findfile -2 overrides __overrides && [ -d "${__overrides}" ]; then
    abinfo "Deploying files in overrides ..."
	cp -arvT "${__overrides}"/ "$PKGDIR/" || \
		abdie "Failed to deploy files in overrides: $?."
fi
