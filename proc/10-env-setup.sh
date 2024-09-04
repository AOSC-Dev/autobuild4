#!/bin/bash
##10-env-setup: Setting up common environmental variables
##@copyright GPL-2.0+

# some of the env variables are handled in native code

abinfo 'Setting $HOME to /root ...'
export HOME="/root"

# Note: Perl installs its core scripts in /usr/bin/core_perl.
# We want to minimise profile script loading, so handle it here.
abinfo 'Setting up /usr/bin/core_perl as part of the $PATH ...'
export PATH="$PATH:/usr/bin/core_perl"

if [ -e /usr/lib/hook_uname.so ]; then
    abinfo 'hook_uname.so detected, preloading ...'
    export LD_PRELOAD="/usr/lib/hook_uname.so:$LD_PRELOAD"
fi
