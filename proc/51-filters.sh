#!/bin/bash
##proc/filter.sh: Now we run the filters
##@copyright GPL-2.0+

pushd "$PKGDIR" > /dev/null || exit 127

for ii in "${AB_FILTERS[@]}"; do
	abinfo "Running post-build filter: $ii ..."
	"$ii"
done

popd > /dev/null || exit 128
