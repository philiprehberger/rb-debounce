# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Limits execution to at most once per interval.
    #
    # Unlike {Debouncer}, which delays until calls stop, Throttler guarantees
    # a maximum execution frequency regardless of how often {#call} is invoked.
    #
    # @example
    #   throttler = Philiprehberger::Debounce.throttle(interval: 1.0) { |x| puts x }
    #   10.times { throttler.call("hi") }  # executes at most once per second
    class Throttler
      # @param interval [Float] minimum time between executions in seconds
      # @param leading [Boolean] fire on the leading edge
      # @param trailing [Boolean] fire on the trailing edge
      # @param on_execute [Proc, nil] callback after block executes, receives return value
      # @param on_cancel [Proc, nil] callback when cancel is invoked
      # @param on_flush [Proc, nil] callback when flush is invoked
      # @param block [Proc] the block to execute
      def initialize(interval:, leading: true, trailing: false, on_execute: nil, on_cancel: nil, on_flush: nil, on_error: nil, &block)
        raise ArgumentError, 'block is required' unless block
        raise ArgumentError, 'interval must be positive' unless interval.positive?
        raise ArgumentError, 'at least one of leading or trailing must be true' if !leading && !trailing

        @interval = interval
        @leading = leading
        @trailing = trailing
        @on_execute = on_execute
        @on_cancel = on_cancel
        @on_flush = on_flush
        @on_error = on_error
        @block = block
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @last_args = nil
        @pending = false
        @trailing_scheduled = false
        @last_execution_time = nil
        @call_count = 0
        @execution_count = 0
        @last_result = nil
      end

      # Invoke the throttler with optional arguments.
      #
      # If enough time has elapsed since the last execution, the block runs
      # immediately (leading edge). Otherwise the arguments are stored and the
      # block fires at the end of the current interval (trailing edge).
      #
      # @param args [Array] arguments forwarded to the block
      # @return [void]
      def call(*args)
        @mutex.synchronize do
          @call_count += 1
          now = monotonic_now
          @last_args = args
          @pending = true

          if @last_execution_time.nil? || (now - @last_execution_time) >= @interval
            # Enough time has passed — fire immediately if leading
            if @leading
              @last_execution_time = now
              @pending = false
              execute(args)
            elsif @trailing
              schedule_trailing
            end
          elsif @trailing
            schedule_trailing
          end
        end
      end

      # Cancel any pending trailing execution.
      #
      # @return [void]
      def cancel
        @mutex.synchronize do
          @pending = false
          @last_args = nil
          @condition.signal
        end

        invoke_callback(@on_cancel)
      end

      # Execute the pending block immediately and cancel the trailing timer.
      #
      # @return [void]
      def flush
        args = nil
        should_execute = false

        @mutex.synchronize do
          if @pending
            args = @last_args
            should_execute = true
            @pending = false
            @last_args = nil
            @last_execution_time = monotonic_now
            @condition.signal
          end
        end

        execute(args) if should_execute
        invoke_callback(@on_flush)
      end

      # Whether there is a pending trailing execution.
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

      # Returns metrics about throttler usage.
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

      def schedule_trailing
        return if @trailing_scheduled

        @trailing_scheduled = true

        Thread.new do
          @mutex.synchronize do
            remaining = if @last_execution_time
                          @interval - (monotonic_now - @last_execution_time)
                        else
                          @interval
                        end

            @condition.wait(@mutex, [remaining, 0].max) if remaining.positive?

            if @pending
              args = @last_args
              @last_execution_time = monotonic_now
              @pending = false
              @last_args = nil
              @trailing_scheduled = false
              execute(args)
            else
              @trailing_scheduled = false
            end
          end
        end
      end

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
