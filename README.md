# philiprehberger-debounce

[![Tests](https://github.com/philiprehberger/rb-debounce/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-debounce/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-debounce.svg)](https://rubygems.org/gems/philiprehberger-debounce)
[![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-debounce)](https://github.com/philiprehberger/rb-debounce/releases)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-debounce)](https://github.com/philiprehberger/rb-debounce/commits/main)
[![License](https://img.shields.io/github/license/philiprehberger/rb-debounce)](LICENSE)
[![Bug Reports](https://img.shields.io/github/issues/philiprehberger/rb-debounce/bug)](https://github.com/philiprehberger/rb-debounce/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Feature Requests](https://img.shields.io/github/issues/philiprehberger/rb-debounce/enhancement)](https://github.com/philiprehberger/rb-debounce/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Debounce and throttle decorators for Ruby method calls

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-debounce'
```

Or install directly:

```bash
gem install philiprehberger-debounce
```

## Usage

```ruby
require 'philiprehberger/debounce'

# Debounce: delays execution until 0.5s of inactivity
debouncer = Philiprehberger::Debounce.debounce(wait: 0.5) { |query| search(query) }
debouncer.call('ruby')
debouncer.call('ruby gems')   # resets the timer
debouncer.call('ruby gems 3') # only this one fires after 0.5s
```

### Throttle

```ruby
# Throttle: executes at most once per second
throttler = Philiprehberger::Debounce.throttle(interval: 1.0) { |event| log(event) }
throttler.call('click') # fires immediately
throttler.call('click') # ignored (within interval)
sleep 1.0
throttler.call('click') # fires again
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

### Max Wait

```ruby
# Force execution after 3 seconds even if calls keep arriving
debouncer = Philiprehberger::Debounce.debounce(wait: 0.5, max_wait: 3.0) do |query|
  search(query)
end
```

### Execution Callbacks

```ruby
debouncer = Philiprehberger::Debounce.debounce(
  wait: 0.5,
  on_execute: ->(result) { logger.info("Executed: #{result}") },
  on_cancel: -> { logger.info('Cancelled') },
  on_flush: -> { logger.info('Flushed') }
) { |query| search(query) }
```

### Metrics

```ruby
debouncer = Philiprehberger::Debounce.debounce(wait: 0.5) { |q| search(q) }

10.times { debouncer.call('test') }
sleep 0.6

debouncer.metrics
# => { call_count: 10, execution_count: 1, suppressed_count: 9 }

debouncer.reset_metrics
```

### Pending Args

```ruby
debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { |q| search(q) }

debouncer.call('ruby')
debouncer.pending_args # => ['ruby']
debouncer.cancel
debouncer.pending_args # => nil
```

### Keyed Debouncing

```ruby
# Debounce per key independently
keyed = Philiprehberger::Debounce.keyed(wait: 0.5) { |query| search(query) }

keyed.call(:user_1, 'ruby')   # debounces independently
keyed.call(:user_2, 'python') # debounces independently

keyed.pending_keys  # => [:user_1, :user_2]
keyed.cancel(:user_1)
keyed.cancel_all
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
| `.debounce(wait:, leading: false, trailing: true, max_wait: nil, on_execute: nil, on_cancel: nil, on_flush: nil, &block)` | Create a debouncer that delays execution |
| `.throttle(interval:, leading: true, trailing: false, on_execute: nil, on_cancel: nil, on_flush: nil, &block)` | Create a throttler that limits execution rate |
| `.keyed(wait:, leading: false, trailing: true, max_wait: nil, on_execute: nil, on_cancel: nil, on_flush: nil, &block)` | Create a keyed debouncer for per-key debouncing |

### `Debouncer`

| Method | Description |
|--------|-------------|
| `#call(*args)` | Invoke the debouncer, resetting the timer |
| `#cancel` | Cancel any pending execution |
| `#flush` | Execute immediately if pending |
| `#pending?` | Whether an execution is pending |
| `#pending_args` | Returns the pending arguments, or nil |
| `#metrics` | Returns `{ call_count:, execution_count:, suppressed_count: }` |
| `#reset_metrics` | Resets all metric counters to zero |

### `Throttler`

| Method | Description |
|--------|-------------|
| `#call(*args)` | Invoke the throttler, rate-limited |
| `#cancel` | Cancel any pending trailing execution |
| `#flush` | Execute immediately if pending |
| `#pending?` | Whether a trailing execution is pending |
| `#pending_args` | Returns the pending arguments, or nil |
| `#metrics` | Returns `{ call_count:, execution_count:, suppressed_count: }` |
| `#reset_metrics` | Resets all metric counters to zero |

### `KeyedDebouncer`

| Method | Description |
|--------|-------------|
| `#call(key, *args)` | Invoke the debouncer for a specific key |
| `#cancel(key)` | Cancel pending execution for a specific key |
| `#cancel_all` | Cancel all pending executions |
| `#pending_keys` | List keys with pending executions |

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

## Support

- [Bug reports](https://github.com/philiprehberger/rb-debounce/issues)
- [Feature requests](https://github.com/philiprehberger/rb-debounce/issues)
- [GitHub Sponsors](https://github.com/sponsors/philiprehberger)

## License

[MIT](LICENSE)
