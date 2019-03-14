# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "method-tracer"
  spec.version       = "1.1.2"
  spec.authors       = ["iaintshine"]
  spec.email         = ["bodziomista@gmail.com"]

  spec.summary       = %q{OpenTracing instrumentation for Ruby methods}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/iaintshine/ruby-method-tracer"
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = ">= 2.2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]


  spec.add_dependency 'opentracing', '>= 0.3.1', '< 0.6.0'

  spec.add_development_dependency "tracing-matchers", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
