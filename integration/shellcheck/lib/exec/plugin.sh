# shellcheck shell=bash

# Bio Plugin Maven
# Provides number of handy functions to use in your plan
#
# Variables:
# None
#
# Functions
# `do_maven_setup_cache` - caches maven repository into studio cache
# `pkg_maven_version` - returns version from pom.xml, truncating snapshot

do_maven_setup_cache() {
    mkdir -p                                                    "$HAB_CACHE_ARTIFACT_PATH/studio_cache/mvn"
    set_buildtime_env MAVEN_OPTS "$MAVEN_OPTS -Dmaven.repo.local=$HAB_CACHE_ARTIFACT_PATH/studio_cache/mvn"
}

# Read pom.xml and detect current version, truncating snapshot
# TODO: without lightweight xmllint or other parser this is only realiable way to detect version
pkg_maven_version() {
    # shellcheck disable=SC2016
    mvn -Dexec.executable='echo' -Dexec.args='${project.version}' --non-recursive exec:exec -q | sed 's/-SNAPSHOT$//'
}
