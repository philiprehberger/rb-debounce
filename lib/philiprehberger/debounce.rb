# frozen_string_literal: true

require_relative 'debounce/version'
require_relative 'debounce/debouncer'
require_relative 'debounce/throttler'
require_relative 'debounce/keyed_debouncer'
require_relative 'debounce/rate_limiter'
require_relative 'debounce/coalescer'
require_relative 'debounce/mixin'

module Philiprehberger
  # Debounce and throttle decorators for Ruby method calls
  module Debounce
    class Error < StandardError; end

    # Create a new debouncer that delays execution until the wait period
    # elapses without new calls.
    #
    # @param wait [Float] delay in seconds
    # @param leading [Boolean] fire on the leading edge (default: false)
    # @param trailing [Boolean] fire on the trailing edge (default: true)
    # @param max_wait [Float, nil] maximum time to wait before forcing execution
    # @param on_execute [Proc, nil] callback after block executes, receives return value
    # @param on_cancel [Proc, nil] callback when cancel is invoked
    # @param on_flush [Proc, nil] callback when flush is invoked
    # @yield [*args] the block to execute after the debounce period
    # @return [Debouncer]
    def self.debounce(wait:, leading: false, trailing: true, max_wait: nil, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)
      Debouncer.new(
        wait: wait, leading: leading, trailing: trailing, max_wait: max_wait,
        on_execute: on_execute, on_cancel: on_cancel, on_flush: on_flush, on_error: on_error, &block
      )
    end

    # Create a new throttler that limits execution to at most once per interval.
    #
    # @param interval [Float] minimum time between executions in seconds
    # @param leading [Boolean] fire on the leading edge (default: true)
    # @param trailing [Boolean] fire on the trailing edge (default: false)
    # @param on_execute [Proc, nil] callback after block executes, receives return value
    # @param on_cancel [Proc, nil] callback when cancel is invoked
    # @param on_flush [Proc, nil] callback when flush is invoked
    # @yield [*args] the block to execute
    # @return [Throttler]
    def self.throttle(interval:, leading: true, trailing: false, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)
      Throttler.new(
        interval: interval, leading: leading, trailing: trailing,
        on_execute: on_execute, on_cancel: on_cancel, on_flush: on_flush, on_error: on_error, &block
      )
    end

    # Create a new keyed debouncer that manages per-key debouncers.
    #
    # @param wait [Float] delay in seconds
    # @param leading [Boolean] fire on the leading edge (default: false)
    # @param trailing [Boolean] fire on the trailing edge (default: true)
    # @param max_wait [Float, nil] maximum time to wait before forcing execution
    # @param max_keys [Integer, nil] maximum number of keys to hold; oldest key is evicted when exceeded
    # @param on_execute [Proc, nil] callback after block executes, receives return value
    # @param on_cancel [Proc, nil] callback when cancel is invoked
    # @param on_flush [Proc, nil] callback when flush is invoked
    # @yield [*args] the block to execute after the debounce period
    # @return [KeyedDebouncer]
    def self.keyed(wait:, leading: false, trailing: true, max_wait: nil, # rubocop:disable Metrics/ParameterLists
                   max_keys: nil, on_execute: nil, on_cancel: nil, on_flush: nil,
                   on_error: nil, &block)
      KeyedDebouncer.new(
        wait: wait, leading: leading, trailing: trailing, max_wait: max_wait, max_keys: max_keys,
        on_execute: on_execute, on_cancel: on_cancel, on_flush: on_flush, on_error: on_error, &block
      )
    end

    # Create a new sliding window rate limiter.
    #
    # @param limit [Integer] maximum number of requests per window
    # @param window [Numeric] window size in seconds
    # @return [RateLimiter]
    def self.rate_limiter(limit:, window:)
      RateLimiter.new(limit: limit, window: window)
    end

    # Create a new coalescer that batches arguments into a single invocation.
    #
    # @param wait [Numeric] delay in seconds before flushing the batch
    # @yield [Array] receives an array of argument arrays from all queued calls
    # @return [Coalescer]
    def self.coalesce(wait:, on_error: nil, &block)
      Coalescer.new(wait: wait, on_error: on_error, &block)
    end
  end
end
