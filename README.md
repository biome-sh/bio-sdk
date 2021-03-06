# The Biome SDK

This project aimed to enhance habitat development experience by providing additional `hab`-commands.

**IN DEVELOPMENT**

# Quick Start

## Use in Biome Studio

Add to `.studiorc` or run manually in studio:

``` bash
# By default all required tools like shellcheck, bats are not installed automatically.
# This reduces install time and adds flexibility.

bio pkg install -fb biome/bio-sdk
bio pkg install -fb core/shellcheck
bio pkg install -fb ya/tomlcheck
```

## Install as CLI

Make sure you have required binaries, like `shellcheck`.

``` bash
sudo bio pkg install -fb biome/bio-sdk
```

## Use in build process

Update your `plan.sh`:

``` bash
...
# Make sure you have required binaries, like `shellcheck`.
pkg_build_deps+=(biome/bio-sdk core/shellcheck)

...

do_prepare() {
  bio-plan-shellcheck $PLAN_CONTEXT
}
```

# Configuration

Optionally you can add `plan.toml` file into `$PLAN_CONTEXT`, near the `plan.sh` file or in parent directory.

Plan Configuration principles are:

* Each section name maps to a corresponding `bio-plan-<thing>` cli.
* Each command line option maps to corresponding option inside the section
* Configuration applies in the following order (last wins):
* * Default Options (sane defaults are embedded into cli)
* * User Options (provided by `plan.toml`)
* * Command line options (specified by user in command line)
* For each `list`-like option:
* *  `add-list` and `remove-list` options are generated
* * Final `list` option is generated by `add-list - remove-list` formula.
* Some options are actually `path` options. You can use globs:
* * `plan.sh` - exactly file `plan.sh`
* * `*/habitat/plan.sh` - files `plan.sh` in any directory with the `habitat` sub-directory
* * `src/**/plan.sh` - files `plan.sh` in `src` and its sub-directories. **On huge trees can be slow**
* * All file path-s are either expanded to a full path or treated from `$PLAN_CONTEXT`s directory

## Configuration Example

Here is `plan.toml` example:

``` toml
# Name of the bio-plan-<thing>
[shellcheck]
# Debug can be turned on separately for each cli
debug = true

# You can glob outside of context
add-path = ["../../*.sh"]

# Remove applied after add. `hooks` directory by default added. You can exclude hook
remove-path = ["hook/annoying-hook"]

# Make shellcheck also exclude SC2154
add-exclude = ["SC2154"]

# By default shellcheck has the following excludes:
# ['SC1090', 'SC1091', 'SC2034']
# I don't want to ignore SC1090, so remove from exclude list:
remove-exclude = ["SC1090"]

[tomlcheck]
# check also all toml files in the config directory
add-path = ["config/*.toml"]

[rendercheck]
# Make bio-plan-render to print templates to stdout
print = true
```

# Commands

## bio-plan-tomlcheck

Validates your toml files using `tomlcheck`.

## bio-plan-shellcheck

Validates your shell scripts using `shellcheck`

## bio-plan-rendercheck

Renders and test your configuration. By default `bio-plan-rendercheck` renders all configuration to `results/tests/render/default` directory.

`bio-plan-rendercheck` works with suites - directories with or without files. By default it uses `tests/render/*` directories relative to plan context. If no suites found emulates empty default one.

For each suite `bio-plan-rendercheck` tries to load `user.toml`, `mock-data.json`, `default.toml` from `suite` directory, suites' parent directory or from plan context directory.
Each suite `bio-plan-rendercheck` renders templates into `results/tests/render/<suite>`
For each suite `bio-plan-rendercheck` compares using `diff` rendered files in `results/tests/render/<suite>` with `tests/render/<suite>` in plan context.

If expected template or config is absent it safely ignored.

You can test different scenarios using `suites`. Let imagine we need to test 3 configuration scenarios for a package:

* `standalone` - configuration with most defaults
* `cluster` - mode for service rings
* `custom` - custom user configuration for some edge cases

Create suites directories:

```bash
mkdir -p tests/render/{standalone,cluster,custom}
```

Create mock data files. We can share same file by creating it in the suites' parent directory:

```bash
vim tests/render/mock-data.json

# But for cluster suite we want another mock-data
vim tests/render/cluster/mock-data.json
```

Create custom user configuration:

```bash
vim tests/render/custom/user.toml
```

Run rendering:

```bash
bio-plan-rendercheck
```

On success you will get number of rendered files:

```
results/tests/render/standalone/config/config.json
results/tests/render/standalone/hooks/run
results/tests/render/cluster/config/config.json
results/tests/render/cluster/hooks/run
results/tests/render/custom/config/config.json
results/tests/render/custom/hooks/run
```

Now inspect files. If they are ok we can easily convert them to _expected_ templates:

```bash
cp -r results/tests tests
```

Now suites contain configuration files so `bio-plan-rendercheck` will compare _expected_ and _actual_.


## bio-depot-sync

This command helps to mirror/sync Habitat/Biome SaaS Builder with another Builder, usually on-prem one.

1. It mirrors whole channel from specified origin
2. It skips artifacts already exists in dest builder
3. It does not create any temporary artifact files and safes disk space
4. If package exist on destination it ensures that package promoted to specified channel

```
bio-depot-sync (options)
        --cache FILE                 Sync cache for resume to work. Default: /tmp/bio-depot-sync.json
        --channel CHANNEL            Channel to mirror. Default: stable
        --dest-auth-token TOKEN      Destination auth token to use.
        --dest-depot URL             Destination depot to sync artifacts from. Default: https://bldr.habitat.sh
        --latest-release             If true - copy only latest release for each version.
        --latest-version             If true - copy only latest version for each package.
        --origin ORIGIN              Origin to mirror. Default: core
        --read-timeout TIMEOUT       Timeout for Net::HTTP operations. Default: 120.
        --source-auth-token TOKEN    Source auth token to use.
        --source-depot URL           Source depot to sync artifacts from. Default: https://bldr.habitat.sh
```

Usage example:

```
bio pkg install -fb ya/bio-sdk
for origin in core habitat chef ya; do
  echo bio-depot-sync --origin $origin --dest-depot $builder_url --dest-auth-token $auth_token --latest-version
done
```


# TODO

Possible commands:

* TODO: bio-plan-bats
* TODO: bio-plan-inspec
* TODO: bio-plan-delmo
* TODO: bio-plan-format - is it really needed?
* TODO: bio-plan-precommit - integration with precommit?
* TODO: bio-plan-service - service management lifecycle during build (for tests: up deps, run test, up main service, run test, down, etc)

Features:

* Better TUI

# Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

# Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/biome-sh/bio-sdk](https://github.com/biome-sh/bio-sdk).

# License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
