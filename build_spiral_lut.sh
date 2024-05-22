#!/bin/bash

set -euo pipefail

DEBIAN_CODENAME="bookworm"
DEBIAN_CONTENTS="http://ftp.debian.org/debian/dists/${DEBIAN_CODENAME}/main/Contents-amd64.gz"
DEBIAN_CONTENTS_FILE="$(mktemp)"

ROOT_DIR="$(dirname "$0")/data"

SONAME_REGEX='^/?usr/lib/(?:x86_64-linux-gnu/)(?P<key>lib[a-zA-Z0-9\-\._+]+\.so(?:\.[0-9]+)*)\s+[a-zA-Z0-9]+/(?P<value>[a-zA-Z0-9\.\-+]+)$'

function generate_lut {
	zcat "$1" | rg "$2" -or '$key,$value' > "$3"
}

echo "Downloading Contents-amd64.gz ..."
curl -fSL "${DEBIAN_CONTENTS}" > "$DEBIAN_CONTENTS_FILE"

echo "Generating LUT for SONAME lookup to $ROOT_DIR/lut_sonames..."
generate_lut "$DEBIAN_CONTENTS_FILE" "$SONAME_REGEX" "$ROOT_DIR/lut_sonames"
