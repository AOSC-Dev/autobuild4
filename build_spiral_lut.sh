#!/bin/bash

set -euo pipefail

UBUNTU_CODENAME="noble"
UBUNTU_CONTENTS="http://archive.ubuntu.com/ubuntu/dists/${UBUNTU_CODENAME}/Contents-amd64.gz"
UBUNTU_CONTENTS_FILE="$(mktemp)"

ROOT_DIR="$(dirname "$0")/data"

SONAME_REGEX='^/?usr/lib/(?:x86_64-linux-gnu/)(?P<key>lib[a-zA-Z0-9\-\._+]+\.so(?:\.[0-9]+)*)\s+([a-zA-Z0-9]+/){0,2}(?P<value>[a-zA-Z0-9\.\-+]+)$'

function generate_lut {
	zcat "$1" | rg "$2" -or '$key,$value' | sort | uniq > "$3"
}

echo "Downloading Contents-amd64.gz ..."
curl -fSL "${UBUNTU_CONTENTS}" > "$UBUNTU_CONTENTS_FILE"

echo "Generating LUT for SONAME lookup to $ROOT_DIR/lut_sonames..."
generate_lut "$UBUNTU_CONTENTS_FILE" "$SONAME_REGEX" "$ROOT_DIR/lut_sonames"
