# The Habitat SDK

This project aimed to enhance habitat development experience by provided set of `hab-plan`-packages:

**IN DEVELOPMENT**

# Quick Start

## In Habitat Studio

Update your `plan.sh`:

```bash
...

pkg_build_deps+=(ya/hab-sdk core/shellcheck)

...

do_prepare() {
  hab-plan-shellcheck $PLAN_CONTEXT
}
```

## Install as CLI

TODO: Deal with OS dependencies. `hab pkg exec` prevents to use OS `shellcheck` if `hab-sdk` hasn't explict dependency.

```bash
sudo hab pkg install ya/hab-sdk
```


# Plan Commands

## hab-plan-shellcheck

## hab-plan-tomlcheck

# Depot Commands

## hab-depot-sync



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/habitat-plans/hab-sdk](https://github.com/habitat-plans/hab-sdk).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
