#!/bin/bash -e
source "ab4-prelude.sh"

abspiral_from_sonames libgtk-3.so
if [[ "${__ABSPIRAL_PROVIDES_SONAMES[*]}" = 'libgtk-3-dev' ]]; then
    echo "Spiral test passed."
else
    echo "Inferred names: ${__ABSPIRAL_PROVIDES_SONAMES[*]}"
    abdie 'Spiral test failed.'
fi

abspiral_from_sonames libQt5QuickParticles.so.5
if [[ "${__ABSPIRAL_PROVIDES_SONAMES[*]}" = 'libqt5quickparticles5 libqt5quickparticles5-gles qtdeclarative5-dev' ]]; then
    echo "Spiral test passed."
else
    echo "Inferred names: ${__ABSPIRAL_PROVIDES_SONAMES[*]}"
    abdie 'Spiral test failed.'
fi
