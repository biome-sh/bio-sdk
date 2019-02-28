# shellcheck shell=bash

pkg_origin=ya
pkg_name=hab-sdk
pkg_version=$(tr -d '\n' < ../VERSION)
pkg_description="The Habitat SDK"

pkg_maintainer="Yauhen Artsiukhou <jsirex@gmail.com>"
pkg_license=("MIT")

pkg_deps=(core/ruby)
pkg_build_deps=(core/git)
pkg_bin_dirs=(bin)

do_setup_environment() {
    # I don't use set_runtime_env because this package designed to be used by other habitat plans
    # Setting runtime env may conflict with ruby-based packages.
    export GEM_HOME="$pkg_prefix/rubygems"
    export GEM_PATH="$pkg_prefix/rubygems"
}

do_build() {
    gem build "$pkg_name.gemspec" && mv "$pkg_name-$pkg_version.gem" "$CACHE_PATH"
}

do_install() {
    build_line "GEM_HOME = '$GEM_HOME'"
    build_line "GEM_PATH = '$GEM_PATH'"
    gem install "$CACHE_PATH/$pkg_name-$pkg_version.gem" --no-document --no-wrappers

    for cli in "$GEM_HOME/bin/"*; do
        if [ -L "$cli" ]; then
            build_line "Rendering wrapper for $(basename "$cli")"
            ruby_wrapper "$(readlink "$cli")"
        else
            warn "Skipping wrapper for $cli - not a symlink"
        fi
    done
}

do_strip() {
    return 0
}

# Wraps regular ruby script according to current GEM_HOME with appropriate LOAD_PATH
ruby_wrapper() {
    local cli_path="$1"
    local ruby_path="$(pkg_path_for core/ruby)/bin/ruby"

    local cli_name="$(basename "$cli_path")"

    cat <<EOF > "$pkg_prefix/bin/$cli_name"
#!$ruby_path

# This is automatically generate wrapper for $pkg_name $pkg_version

# Make sure absolute path
GEM_HOME = File.expand_path("$GEM_HOME")
LIBDIRS = File.join(GEM_HOME, 'gems', '*','lib')

Dir.glob(LIBDIRS).each do |libdir|
  \$LOAD_PATH.unshift(libdir) unless \$LOAD_PATH.include?(libdir)
end

load "$cli_path"
EOF
    chmod +x "$pkg_prefix/bin/$cli_name"
}
