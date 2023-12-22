#!/bin/bash
##20-ruby.sh: Builds Ruby GEMs
##@copyright GPL-2.0+

build_ruby_probe(){
	# [ -f "$SRCDIR"/*.gem ]
	false;
}

build_ruby_configure() {
	BUILD_START
}

build_ruby_build(){
	local GEMDIR
	GEMDIR="$(ruby -e'puts Gem.default_dir')"
	BUILD_READY
	abinfo "Building and installing Ruby (Gem) package ..."
	gem install --ignore-dependencies --no-user-install \
		-i "$PKGDIR/$GEMDIR" -n "$PKGDIR/usr/bin" "$PKGNAME-$PKGVER.gem" \
		|| abdie "Failed to build and install Ruby (Gem) package: $?."
	abinfo 'Removing Gem cache from $PKGDIR ...'
	rm -v "$PKGDIR/$GEMDIR/cache/"* \
		|| abdie "Failed to remove Gem cache from PKGDIR: $?."
}

build_ruby_install() {
    BUILD_FINAL
}

ab_register_template ruby -- ruby gem
