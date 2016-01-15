# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hocho/version'

Gem::Specification.new do |spec|
  spec.name          = "hocho"
  spec.version       = Hocho::VERSION
  spec.authors       = ["sorah (Shota Fukumori)"]
  spec.email         = ["her@sorah.jp"]

  spec.summary       = %q{Server provisioning tool with itamae}
  spec.homepage      = "https://github.com/sorah/hocho"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor"
  spec.add_dependency "itamae"
  spec.add_dependency "net-ssh"
  spec.add_dependency "hashie"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
