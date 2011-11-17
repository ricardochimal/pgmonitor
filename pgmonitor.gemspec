# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pgmonitor/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ricardo Chimal, Jr."]
  gem.email         = ["ricardo@heroku.com"]
  gem.description   = %q{Monitor pg connections on a postgres server}
  gem.summary       = %q{Monitor pg connections on a postgres server}
  gem.homepage      = "http://github.com/ricardochimal/pgmonitor"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "pgmonitor"
  gem.require_paths = ["lib"]
  gem.version       = Pgmonitor::VERSION
end
