# philiprehberger-debounce

[![Tests](https://github.com/philiprehberger/rb-debounce/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-debounce/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-debounce.svg)](https://rubygems.org/gems/philiprehberger-debounce)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-debounce)](https://github.com/philiprehberger/rb-debounce/commits/main)

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

### Error Handling

```ruby
# Block exceptions are swallowed by default to keep timer threads alive.
# Provide on_error: to observe them.
debouncer = Philiprehberger::Debounce.debounce(
  wait: 0.5,
  on_error: ->(error) { logger.error("debounced job failed: #{error.message}") }
) { |query| search(query) }
```

`on_error:` is supported by `.debounce`, `.throttle`, `.keyed`, and `.coalesce`.

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
keyed.size          # => 2
keyed.cancel(:user_1)
keyed.cancel_all
```

After the block fires for a key, that key is automatically removed from internal state. The same key can be reused in subsequent calls.

```ruby
# Limit the number of tracked keys (oldest key evicted when limit is reached)
keyed = Philiprehberger::Debounce.keyed(wait: 0.5, max_keys: 100) { |query| search(query) }

keyed.call(:user_1, 'ruby')
keyed.call(:user_2, 'python')
# If a 101st distinct key arrives, :user_1 is cancelled and removed first
```

### Rate Limiting

```ruby
# Allow at most 5 requests per 10-second window
limiter = Philiprehberger::Debounce.rate_limiter(limit: 5, window: 10)

result = limiter.call(:user_1)
# => { allowed: true, remaining: 4, retry_after: 0 }

# After exceeding the limit:
# => { allowed: false, remaining: 0, retry_after: 7.3 }

limiter.reset(:user_1) # clear history for a key
```

### Coalescing

```ruby
# Collect arguments from multiple calls and flush as a batch
coalescer = Philiprehberger::Debounce.coalesce(wait: 0.5) do |batched_args|
  bulk_insert(batched_args)
end

coalescer.call('row1')
coalescer.call('row2')
coalescer.call('row3')
# After 0.5s of inactivity, block fires with [['row1'], ['row2'], ['row3']]

coalescer.flush          # fire immediately with queued args
coalescer.cancel         # discard queued args
coalescer.pending_count  # number of queued calls
```

### Last Result

```ruby
debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { |x| x.upcase }
debouncer.call('hello')
sleep 0.15
debouncer.last_result # => "HELLO"

throttler = Philiprehberger::Debounce.throttle(interval: 0.1) { |x| x * 2 }
throttler.call(5)
throttler.last_result # => 10
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
| `.debounce(wait:, leading: false, trailing: true, max_wait: nil, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)` | Create a debouncer that delays execution |
| `.throttle(interval:, leading: true, trailing: false, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)` | Create a throttler that limits execution rate |
| `.keyed(wait:, leading: false, trailing: true, max_wait: nil, max_keys: nil, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)` | Create a keyed debouncer for per-key debouncing |
| `.rate_limiter(limit:, window:)` | Create a sliding window rate limiter |
| `.coalesce(wait:, on_error: nil, &block)` | Create a coalescer that batches arguments |

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
| `#last_result` | Returns the result of the last block execution |

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
| `#last_result` | Returns the result of the last block execution |

### `KeyedDebouncer`

| Method | Description |
|--------|-------------|
| `#call(key, *args)` | Invoke the debouncer for a specific key |
| `#cancel(key)` | Cancel pending execution for a specific key |
| `#cancel_all` | Cancel all pending executions |
| `#flush(key)` | Flush pending execution for a specific key immediately |
| `#flush_all` | Flush all pending keyed debouncers immediately |
| `#pending_keys` | List keys with pending executions |
| `#size` | Number of active keyed debouncers currently held (O(1)) |

Completed keys are automatically removed after execution. Use `max_keys:` to cap the number of tracked keys; the oldest key is evicted when the limit is exceeded.

### `RateLimiter`

| Method | Description |
|--------|-------------|
| `#call(key = :default)` | Check rate limit, returns `{ allowed:, remaining:, retry_after: }` |
| `#reset(key = :default)` | Clear request history for a key |

### `Coalescer`

| Method | Description |
|--------|-------------|
| `#call(*args)` | Queue arguments for the next batch |
| `#flush` | Fire the block immediately with queued args |
| `#cancel` | Discard all queued arguments |
| `#pending_count` | Number of queued calls |
| `#pending_args` | Snapshot of queued argument arrays |

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

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-debounce)

🐛 [Report issues](https://github.com/philiprehberger/rb-debounce/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-debounce/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
