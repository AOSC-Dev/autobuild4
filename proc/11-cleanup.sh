#!/bin/bash
##proc/cleanup: We always want our butt free of old build output
##@copyright GPL-2.0+
# Clean up!

if bool "$ABCLEAN"; then
	abinfo "Pre-build clean up..."
	rm -rf "$SRCDIR"/ab{dist,dist-dbg,-dpkg,spec,scripts}
else
	aberr "Disabling clean up is no longer allowed."
    exit 1
fi
