# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Delays execution until the wait period elapses without new calls.
    #
    # When {#call} is invoked, any pending execution is cancelled and the timer
    # restarts. The block only fires once the caller stops calling for the
    # full +wait+ duration.
    #
    # @example
    #   debouncer = Philiprehberger::Debounce.debounce(wait: 0.3) { puts "saved" }
    #   debouncer.call   # resets timer
    #   debouncer.call   # resets timer again — block fires 0.3s after this call
    class Debouncer
      # @param wait [Float] delay in seconds
      # @param leading [Boolean] fire on the leading edge
      # @param trailing [Boolean] fire on the trailing edge
      # @param max_wait [Float, nil] maximum time to wait before forcing execution
      # @param on_execute [Proc, nil] callback after block executes, receives return value
      # @param on_cancel [Proc, nil] callback when cancel is invoked
      # @param on_flush [Proc, nil] callback when flush is invoked
      # @param block [Proc] the block to execute
      def initialize(wait:, leading: false, trailing: true, max_wait: nil, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)
        raise ArgumentError, 'block is required' unless block
        raise ArgumentError, 'wait must be positive' unless wait.positive?
        raise ArgumentError, 'at least one of leading or trailing must be true' if !leading && !trailing
        raise ArgumentError, 'max_wait must be positive' if max_wait && !max_wait.positive?

        @wait = wait
        @leading = leading
        @trailing = trailing
        @max_wait = max_wait
        @on_execute = on_execute
        @on_cancel = on_cancel
        @on_flush = on_flush
        @on_error = on_error
        @block = block
        @mutex = Mutex.new
        @pending = false
        @last_args = nil
        @called_leading = false
        @generation = 0
        @call_count = 0
        @execution_count = 0
        @first_call_time = nil
        @last_result = nil
      end

      # Invoke the debouncer with optional arguments.
      #
      # Resets the internal timer. The block will execute after +wait+ seconds
      # of inactivity (trailing edge) or immediately on the first call (leading edge).
      #
      # @param args [Array] arguments forwarded to the block
      # @return [void]
      def call(*args)
        @mutex.synchronize do
          @call_count += 1
          @last_args = args
          @pending = true
          @generation += 1
          current_gen = @generation

          @first_call_time ||= monotonic_now

          # Leading edge: fire immediately on the first call of a new cycle
          if @leading && !@called_leading
            @called_leading = true
            execute(args)
          end

          # Check if max_wait has been exceeded
          if @max_wait && @first_call_time && (monotonic_now - @first_call_time) >= @max_wait
            if @trailing
              args_to_use = @last_args
              @pending = false
              @last_args = nil
              @called_leading = false
              @first_call_time = nil
              execute(args_to_use)
            end
            return
          end

          # Start a new trailing timer
          if @trailing || @leading
            effective_wait = @wait
            if @max_wait && @first_call_time
              remaining_max = @max_wait - (monotonic_now - @first_call_time)
              effective_wait = [effective_wait, remaining_max].min if remaining_max.positive?
            end

            Thread.new do
              sleep effective_wait

              @mutex.synchronize do
                # Only fire if no new calls happened since this timer started
                if @generation == current_gen && @pending
                  if @trailing
                    args_to_use = @last_args
                    @pending = false
                    @last_args = nil
                    @called_leading = false
                    @first_call_time = nil
                    execute(args_to_use)
                  else
                    @pending = false
                    @called_leading = false
                    @first_call_time = nil
                  end
                end
              end
            end
          end
        end
      end

      # Cancel any pending execution.
      #
      # @return [void]
      def cancel
        @mutex.synchronize do
          @generation += 1
          @pending = false
          @last_args = nil
          @called_leading = false
          @first_call_time = nil
        end

        invoke_callback(@on_cancel)
      end

      # Execute the pending block immediately and cancel the timer.
      #
      # @return [void]
      def flush
        args = nil
        should_execute = false

        @mutex.synchronize do
          if @pending
            args = @last_args
            should_execute = true
            @generation += 1
            @pending = false
            @last_args = nil
            @called_leading = false
            @first_call_time = nil
          end
        end

        execute(args) if should_execute
        invoke_callback(@on_flush)
      end

      # Whether there is a pending execution.
      #
      # @return [Boolean]
      def pending?
        @mutex.synchronize { @pending }
      end

      # Returns the arguments that would be passed to the next execution.
      #
      # @return [Array, nil] the pending arguments, or nil if not pending
      def pending_args
        @mutex.synchronize do
          @pending ? @last_args : nil
        end
      end

      # Returns metrics about debouncer usage.
      #
      # @return [Hash] call_count, execution_count, suppressed_count
      def metrics
        @mutex.synchronize do
          {
            call_count: @call_count,
            execution_count: @execution_count,
            suppressed_count: @call_count - @execution_count
          }
        end
      end

      # Returns the result of the last block execution.
      #
      # @return [Object, nil]
      def last_result
        @mutex.synchronize { @last_result }
      end

      # Resets all metric counters to zero.
      #
      # @return [void]
      def reset_metrics
        @mutex.synchronize do
          @call_count = 0
          @execution_count = 0
        end
      end

      private

      def execute(args)
        result = @block.call(*args)
        @execution_count += 1
        @last_result = result
        invoke_callback(@on_execute, result)
        result
      rescue StandardError => e
        # Swallow errors to avoid killing timer threads; surface via on_error if set
        invoke_callback(@on_error, e)
        nil
      end

      def invoke_callback(callback, *args)
        return unless callback

        callback.call(*args)
      rescue StandardError
        nil
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
