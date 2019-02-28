# -*- coding: utf-8 -*-
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hab/sdk/version"

Gem::Specification.new do |spec|
  spec.name          = "hab-sdk"
  spec.version       = Hab::SDK::VERSION
  spec.authors       = ["Yauhen Artsiukhou"]
  spec.email         = ["jsirex@gmail.com"]

  spec.summary       = %q{The Habitat SDK}
  spec.description   = %q{The Habitat SDK: Set of useful CLIs to enhance habitat development experience}
  spec.homepage      = "https://github.com/habitat-plans/hab-sdk"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.post_install_message = Hab::SDK::POST_INSTALL_BANNER

  spec.add_dependency "tomlrb", "~> 1.2"
  spec.add_dependency "cli-ui", "~> 1.2"
  spec.add_dependency "mixlib-shellout", "~> 2.4"
  spec.add_dependency "mixlib-cli", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "pry", "~> 0.12"
end
