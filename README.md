# philiprehberger-debounce

[![Tests](https://github.com/philiprehberger/rb-debounce/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-debounce/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-debounce.svg)](https://rubygems.org/gems/philiprehberger-debounce)
[![License](https://img.shields.io/github/license/philiprehberger/rb-debounce)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Debounce and throttle decorators for Ruby method calls

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-debounce"
```

Or install directly:

```bash
gem install philiprehberger-debounce
```

## Usage

```ruby
require "philiprehberger/debounce"

# Debounce: delays execution until 0.5s of inactivity
debouncer = Philiprehberger::Debounce.debounce(wait: 0.5) { |query| search(query) }
debouncer.call("ruby")
debouncer.call("ruby gems")   # resets the timer
debouncer.call("ruby gems 3") # only this one fires after 0.5s
```

### Throttle

```ruby
# Throttle: executes at most once per second
throttler = Philiprehberger::Debounce.throttle(interval: 1.0) { |event| log(event) }
throttler.call("click") # fires immediately
throttler.call("click") # ignored (within interval)
sleep 1.0
throttler.call("click") # fires again
```

### Leading and Trailing Edges

```ruby
# Leading edge: fire immediately, ignore subsequent calls during wait
debouncer = Philiprehberger::Debounce.debounce(wait: 0.3, leading: true, trailing: false) do |v|
  puts v
end

# Both edges: fire immediately AND after the quiet period
debouncer = Philiprehberger::Debounce.debounce(wait: 0.3, leading: true, trailing: true) do |v|
  puts v
end
```

### Cancel and Flush

```ruby
debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { save_draft }

debouncer.call
debouncer.cancel # cancel pending execution

debouncer.call
debouncer.flush  # execute immediately without waiting
```

### Mixin

```ruby
class SearchController
  include Philiprehberger::Debounce::Mixin

  def search(query)
    # expensive search operation
  end
  debounce_method :search, wait: 0.5

  def log_event(event)
    # logging
  end
  throttle_method :log_event, interval: 1.0
end
```

## API

### `Philiprehberger::Debounce`

| Method | Description |
|--------|-------------|
| `.debounce(wait:, leading: false, trailing: true, &block)` | Create a debouncer that delays execution |
| `.throttle(interval:, leading: true, trailing: false, &block)` | Create a throttler that limits execution rate |

### `Debouncer`

| Method | Description |
|--------|-------------|
| `#call(*args)` | Invoke the debouncer, resetting the timer |
| `#cancel` | Cancel any pending execution |
| `#flush` | Execute immediately if pending |
| `#pending?` | Whether an execution is pending |

### `Throttler`

| Method | Description |
|--------|-------------|
| `#call(*args)` | Invoke the throttler, rate-limited |
| `#cancel` | Cancel any pending trailing execution |
| `#flush` | Execute immediately if pending |
| `#pending?` | Whether a trailing execution is pending |

### `Mixin`

| Method | Description |
|--------|-------------|
| `.debounce_method(name, wait:, leading: false, trailing: true)` | Debounce an instance method |
| `.throttle_method(name, interval:, leading: true, trailing: false)` | Throttle an instance method |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE)
