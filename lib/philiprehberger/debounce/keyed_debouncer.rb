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
      # @param max_keys [Integer, nil] maximum number of keys to hold; oldest key is evicted when exceeded
      # @param on_execute [Proc, nil] callback after block executes
      # @param on_cancel [Proc, nil] callback when cancel is invoked
      # @param on_flush [Proc, nil] callback when flush is invoked
      # @param block [Proc] the block to execute
      def initialize(wait:, leading: false, trailing: true, max_wait: nil, # rubocop:disable Metrics/ParameterLists
                     max_keys: nil, on_execute: nil, on_cancel: nil, on_flush: nil,
                     on_error: nil, &block)
        raise ArgumentError, 'block is required' unless block
        raise ArgumentError, 'max_keys must be a positive integer' if max_keys && (!max_keys.is_a?(Integer) || max_keys < 1)

        @wait = wait
        @leading = leading
        @trailing = trailing
        @max_wait = max_wait
        @max_keys = max_keys
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
        debouncer = @mutex.synchronize { @debouncers.delete(key) }
        debouncer&.cancel
      end

      # Flush the pending execution for a specific key immediately.
      #
      # @param key [Object] the key to flush
      # @return [void]
      def flush(key)
        debouncer = @mutex.synchronize { @debouncers.delete(key) }
        debouncer&.flush
      end

      # Flush all pending keyed debouncers immediately.
      #
      # @return [void]
      def flush_all
        debouncers = @mutex.synchronize do
          current = @debouncers.values
          @debouncers.clear
          current
        end
        debouncers.each(&:flush)
      end

      # Cancel all pending executions.
      #
      # @return [void]
      def cancel_all
        debouncers = @mutex.synchronize do
          current = @debouncers.values
          @debouncers.clear
          current
        end
        debouncers.each(&:cancel)
      end

      # List keys that have pending executions.
      #
      # @return [Array] keys with pending executions
      def pending_keys
        @mutex.synchronize do
          @debouncers.select { |_key, debouncer| debouncer.pending? }.keys
        end
      end

      # Number of active keyed debouncers currently held internally.
      #
      # @return [Integer] count of tracked keys (O(1))
      def size
        @mutex.synchronize do
          @debouncers.size
        end
      end

      private

      def debouncer_for(key)
        evicted = nil
        debouncer = @mutex.synchronize do
          unless @debouncers.key?(key)
            if @max_keys && @debouncers.size >= @max_keys
              oldest_key = @debouncers.keys.first
              evicted = @debouncers.delete(oldest_key) if oldest_key
            end

            user_on_execute = @on_execute
            @debouncers[key] = Debouncer.new(
              wait: @wait,
              leading: @leading,
              trailing: @trailing,
              max_wait: @max_wait,
              on_execute: lambda { |result|
                @mutex.synchronize { @debouncers.delete(key) }
                user_on_execute&.call(result)
              },
              on_cancel: @on_cancel,
              on_flush: @on_flush,
              on_error: @on_error,
              &@block
            )
          end
          @debouncers[key]
        end
        evicted&.cancel
        debouncer
      end
    end
  end
end
