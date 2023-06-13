# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Manages per-key debouncer instances, allowing independent debouncing
    # for different keys using the same configuration.
    #
    # @example
    #   keyed = Philiprehberger::Debounce.keyed(wait: 0.5) { |key, query| search(key, query) }
    #   keyed.call(:user_1, 'ruby')
    #   keyed.call(:user_2, 'python')  # independent debounce timers
    class KeyedDebouncer
      # @param wait [Float] delay in seconds
      # @param leading [Boolean] fire on the leading edge
      # @param trailing [Boolean] fire on the trailing edge
      # @param max_wait [Float, nil] maximum time to wait before forcing execution
      # @param on_execute [Proc, nil] callback after block executes
      # @param on_cancel [Proc, nil] callback when cancel is invoked
      # @param on_flush [Proc, nil] callback when flush is invoked
      # @param block [Proc] the block to execute
      def initialize(wait:, leading: false, trailing: true, max_wait: nil, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)
        raise ArgumentError, 'block is required' unless block

        @wait = wait
        @leading = leading
        @trailing = trailing
        @max_wait = max_wait
        @on_execute = on_execute
        @on_cancel = on_cancel
        @on_flush = on_flush
        @on_error = on_error
        @block = block
        @debouncers = {}
        @mutex = Mutex.new
      end

      # Invoke the debouncer for the given key.
      #
      # @param key [Object] the key to debounce independently
      # @param args [Array] arguments forwarded to the block
      # @return [void]
      def call(key, *args)
        debouncer_for(key).call(*args)
      end

      # Cancel the pending execution for a specific key.
      #
      # @param key [Object] the key to cancel
      # @return [void]
      def cancel(key)
        @mutex.synchronize do
          @debouncers[key]&.cancel
        end
      end

      # Cancel all pending executions.
      #
      # @return [void]
      def cancel_all
        @mutex.synchronize do
          @debouncers.each_value(&:cancel)
        end
      end

      # List keys that have pending executions.
      #
      # @return [Array] keys with pending executions
      def pending_keys
        @mutex.synchronize do
          @debouncers.select { |_key, debouncer| debouncer.pending? }.keys
        end
      end

      private

      def debouncer_for(key)
        @mutex.synchronize do
          @debouncers[key] ||= Debouncer.new(
            wait: @wait,
            leading: @leading,
            trailing: @trailing,
            max_wait: @max_wait,
            on_execute: @on_execute,
            on_cancel: @on_cancel,
            on_flush: @on_flush,
            on_error: @on_error,
            &@block
          )
        end
      end
    end
  end
end
