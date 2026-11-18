#!/bin/bash
##15-rust.sh: Builds Rust + Cargo projects
##@copyright GPL-2.0+

DEFAULT_CARGO_CONFIG=(
--config 'profile.release.lto = true'
--config 'profile.release.incremental = false'
--config 'profile.release.codegen-units = 1'
--config 'profile.release.strip = false'
)

build_rust_prepare_registry() {
	local REGISTRY_URL='https://github.com/rust-lang/crates.io-index'
	local REGISTRY_DIR='github.com-1ecc6299db9ec823'
	local THIS_REGISTRY_DIR="$HOME/.cargo/registry/index/${REGISTRY_DIR}/.git"

	if [ ! -d "${THIS_REGISTRY_DIR}" ]; then
		git clone --bare "${REGISTRY_URL}" "${THIS_REGISTRY_DIR}"
	fi
}

build_rust_get_installed_rust_version() {
    rustc --version | perl -ne '/^rustc\s+(\d+\.\d+\.\d+)\s+\(/ && print"$1\n"'
}

build_rust_probe() {
	[ -f "$SRCDIR"/Cargo.toml ]
}

build_rust_inject_lto() {
	bool "${USECLANG}" \
		|| abdie 'Please set "USECLANG=1" in your defines to enable proper LTO.'
	command -v ld.lld > /dev/null \
		|| abdie 'ld.lld is unavailable. Please add "llvm" to your $BUILDDEP or disable LTO for this architecture.'
}

build_rust_audit() {
	if bool "$NOCARGOAUDIT"; then
		return 0
	fi

	abinfo 'Auditing dependencies...'
	if ! command -v cargo-audit > /dev/null; then
		abdie "cargo-audit not found: $?."
	elif [ -f "$SRCDIR"/Cargo.lock ]; then
		if ! cargo audit; then
			abinfo 'Vulnerabilities detected! Attempting automatic fix ...'
			cargo audit fix \
				|| abdie 'Unable to fix vulnerability! Refusing to continue.'
		fi
	else
		abdie 'No lock file found -- Dependency information unreliable. Unable to conduct audit.'
	fi
}

build_rust_configure() {
	abinfo 'Setting up build environment: $PKG_CONFIG_SYSROOT_DIR= hack ...'
	export PKG_CONFIG_SYSROOT_DIR=/

	BUILD_START

	# FIXME: The cc crate (as of v1.11.2) does not respect the C
	# preprocessor flags, and they are simply ignored as a result.
	#
	# More problematically, this would cause Rust programs with C++
	# bindings, such as oma, to be built with ABI incompatibilities
	# with C++ libraries it links against, causing runtime failures.
	#
	# For instance, on 32-bit architectures with ABI-changing flags
	# `-D_FILE_OFFSET_BITS=64' and `-D_TIME_BITS=64' enabled by
	# default to future proof binaries for Y2038 compatibility. As
	# such, we ran into a scenario where libapt-pkg to be built with
	# 64-bit time_t, whereas oma was still built with 32-bit time_t,
	# as the aforementioned flags was not honoured by the cc crate.
	# During runtime, this would manifest in random crashes due to
	# misalignment in data structures.
	#
	# Issue reported upstream, awaiting upstream response:
	#
	# https://github.com/rust-lang/cc-rs/issues/2107
	#
	# Re-visit if this changes.
	export CFLAGS="$CPPFLAGS $CFLAGS"
	export CXXFLAGS="$CPPFLAGS $CXXFLAGS"

	if bool AB_FLAGS_O3; then
		DEFAULT_CARGO_CONFIG+=(--config 'profile.release.opt-level = 3')
	fi
	if ! bool ABSPLITDBG; then
	    DEFAULT_CARGO_CONFIG+=(--config 'profile.release.debug = 0')
	fi
	[ -f "$SRCDIR"/Cargo.lock ] \
		|| abwarn "This project is lacking the lock file. Please report this issue to the upstream."
	if ! dpkg --compare-versions "$(build_rust_get_installed_rust_version)" ge '1.70.0'; then
		build_rust_prepare_registry
	fi
	if ab_match_arch "ppc64" && \
		! bool "$NOLTO"; then
		build_rust_inject_lto
	fi
}

build_rust_build() {
	BUILD_READY
	abinfo 'Building Cargo package ...'
	install -vd "$PKGDIR/usr/bin/"
	ab_tostringarray CARGO_AFTER
	local manifest
	manifest="$(cargo read-manifest --manifest-path "$SRCDIR"/Cargo.toml || true)"
	abjson_get_item "${manifest}" "['targets'][0]['kind'][0]" _JSON_OUTPUT || true
	if [ "${_JSON_OUTPUT}" = 'bin' ]; then
		cargo install --locked -f --path "$SRCDIR" \
			"${DEFAULT_CARGO_CONFIG[@]}" \
			--root="$PKGDIR/usr/" \
			"${CARGO_AFTER[@]}" \
			|| abdie "Compilation failed: $?."
	else
		abinfo 'Using fallback build method ...'
	  parsed_flags="$(getopt -o ':p' -- "${CARGO_AFTER[@]}" || true)"
	  parsed_flags=(${parsed_flags})
	  if [[ "${parsed_flags}" != '-p' ]]; then
		DEFAULT_CARGO_CONFIG+=('--workspace')
	  fi
	  cargo build "${DEFAULT_CARGO_CONFIG[@]}" \
			--release --locked \
			"${CARGO_AFTER[@]}" \
			|| abdie "Compilation failed: $?."
		abinfo "Installing binaries in the workspace ..."
	  find "$SRCDIR"/target/release \
			-maxdepth 1 \
			-executable \
			-type f ! \
			-name "*.so" \
			-exec 'install' '-Dvm755' '{}' "$PKGDIR/usr/bin/" ';'
	fi
}

build_rust_install() {
	abinfo 'Installing exported shared libraries in the workspace ...'
	for i in "$SRCDIR"/target/release/*.so*; do
		# filter out the compiler plugins
		readelf --wide --dyn-syms "$i" | grep -q '__rustc_proc_macro_decls_[0-9a-f]*__' ||\
			install -Dvm755 "$i" -t "$PKGDIR"/usr/lib/
	done
	abinfo 'Dropping lingering files ...'
	rm -fv "$PKGDIR"/usr/.crates{.toml,2.json}
	BUILD_FINAL
}

ab_register_template -l rust -- rustc cargo readelf
