#!/bin/bash -e
source "ab4-prelude.sh"

abspiral_from_sonames libgtk-3.so
if [[ "${__ABSPIRAL_PROVIDES_SONAMES[*]}" = 'libgtk-3-dev' ]]; then
    echo "Spiral test passed."
    exit 0
else
    echo "Inferred names: ${__ABSPIRAL_PROVIDES_SONAMES[*]}"
    abdie 'Spiral test failed.'
fi
