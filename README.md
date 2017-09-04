[![Build Status](https://travis-ci.org/iaintshine/ruby-method-tracer.svg?branch=master)](https://travis-ci.org/iaintshine/ruby-method-tracer)

# Method::Tracer

The gem provides OpenTracing instrumentation for custom Ruby methods.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'method-tracer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install method-tracer

## Usage

First of all you need to initialize the gem using `Method::Tracer.configure` method. You need to supply an instance of a tracer, and an active span provider - a proc which returns a current active span. The gem plays nicely with [spanmanager](https://github.com/iaintshine/ruby-spanmanager). 

```ruby
require 'spanmanager'
require 'method-tracer'

OpenTracing.global_tracer = SpanManager::Tracer.new(OpenTracing.global_tracer)
Method::Tracer.configure(tracer: OpenTracing.global_tracer,
                        active_span: -> { OpenTracing.global_tracer.active_span })
```

The gem comes in two flavours. You can either use 'magic mode', and include `Method::Tracer` module and then use `trace_method` method, or skip the magic and use `Method::Tracer.trace` class method within your business code. See usage examples below: 

```ruby
class TracedClass
  class << self
    def class_method
    end

    include Method::Tracer
    trace_method :class_method
  end

  def instance_method
    Method::Tracer.trace("inner span") do |span|
      # business code
    end
  end

  include Method::Tracer
  trace_method :instance_method
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iaintshine/ruby-method-tracer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

