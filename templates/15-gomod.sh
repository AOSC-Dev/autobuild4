#!/bin/bash
##15-gomod.sh: Builds Go projects using Go Modules and Go 1.11+
##@copyright GPL-2.0+

ab_go_build() {
	ab_typecheck -a GO_LDFLAGS
	if ! bool ABSPLITDBG || bool ABSTRIP; then
	    GO_LDFLAGS+=(-s -w)
	fi
	(
		set -x
		go install -v -ldflags "${GO_LDFLAGS[*]} -extldflags '-Wl,-z,relro -Wl,-z,now -specs=/usr/lib/autobuild3/specs/hardened-ld'" "$@"
	)
}

build_gomod_probe() {
	[ -f "$SRCDIR"/go.mod ] \
		&& [ -f "$SRCDIR"/go.sum ] # go.sum is required for security reasons
}

build_gomod_configure() {
	BUILD_START
	export GO111MODULE=on
	abinfo 'Note, this build type only works with Go 1.11+ modules'
	[ -f Makefile ] && abwarn "This project might be using other build tools than Go itself."
	if ! bool "$ABSHADOW"; then
		abdie "ABSHADOW must be set to true for this build type: $?."
	fi

	mkdir -pv "$BLDDIR" \
		|| abdie "Failed to create $SRCDIR/abbuild: $?."
	cd "$BLDDIR" \
		|| abdie "Failed to cd $SRCDIR/abbuild: $?."

	for package in "${GO_PACKAGES[@]}"; do
		abinfo "Fetching Go modules ($package) dependencies ..."
		GOPATH="$SRCDIR/abgopath" go get "$SRCDIR/$package" \
			|| abdie "Failed to fetch Go module dependencies: $?."
	done
}

build_gomod_build() {
	BUILD_READY
	mkdir -pv "$PKGDIR/usr/bin/"
	ab_tostringarray GO_BUILD_AFTER

	for package in "${GO_PACKAGES[@]}"; do
		abinfo "Compiling Go module ($package) ..."
		GOPATH="$SRCDIR/abgopath" \
			GOBIN="$PKGDIR/usr/bin/" \
			ab_go_build "${GO_BUILD_AFTER[@]}" "$SRCDIR/$package" \
			|| abdie "Failed to build Go module ($package): $?."
	done

	BUILD_FINAL
}

build_gomod_install() {
	true
}

ab_register_template gomod -- go
