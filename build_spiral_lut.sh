#!/bin/bash

set -euo pipefail

UBUNTU_CODENAMES=("noble" "jammy")

ROOT_DIR="$(dirname "$0")/data"
TEMP_PATH="$(mktemp)"
SONAME_REGEX='^/?usr/lib/(?:x86_64-linux-gnu/)(?P<key>lib[a-zA-Z0-9\-\._+]+\.so(?:\.[0-9]+)*)\s+([a-zA-Z0-9]+/){0,2}(?P<value>[a-zA-Z0-9\.\-+]+)$'

function generate_lut {
	__contents_url="https://mirrors.edge.kernel.org/ubuntu/dists/$1/Contents-amd64.gz"
	__contents_path="$(mktemp)"
	echo "Downloading ${__contents_url} ..."
	curl -fSL "${__contents_url}" > "${__contents_path}"
	echo "Generating LUT from ${__contents_url} ..."
	zcat "${__contents_path}" | rg "$SONAME_REGEX" -or '$key,$value' >> "${TEMP_PATH}"
	rm "${__contents_path}"
}

for codename in "${UBUNTU_CODENAMES[@]}"; do
	generate_lut "$codename"
done

echo "Removing duplicated entries ..."
sort "${TEMP_PATH}" | uniq > "$ROOT_DIR/lut_sonames.csv"
rm "${TEMP_PATH}"
