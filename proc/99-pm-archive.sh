#!/bin/bash
##proc/archive: archives the package.
##@copyright GPL-2.0+
abinfo "Archiving package(s) ..."
abinfo "Using $ABARCHIVE as autobuild archiver ..."
"$ABARCHIVE" AB_PACKAGES
