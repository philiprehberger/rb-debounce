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
      # @param block [Proc] the block to execute
      def initialize(wait:, leading: false, trailing: true, &block)
        raise ArgumentError, 'block is required' unless block
        raise ArgumentError, 'wait must be positive' unless wait.positive?
        raise ArgumentError, 'at least one of leading or trailing must be true' if !leading && !trailing

        @wait = wait
        @leading = leading
        @trailing = trailing
        @block = block
        @mutex = Mutex.new
        @pending = false
        @last_args = nil
        @called_leading = false
        @generation = 0
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
          @last_args = args
          @pending = true
          @generation += 1
          current_gen = @generation

          # Leading edge: fire immediately on the first call of a new cycle
          if @leading && !@called_leading
            @called_leading = true
            execute(args)
          end

          # Start a new trailing timer
          if @trailing || @leading
            Thread.new do
              sleep @wait

              @mutex.synchronize do
                # Only fire if no new calls happened since this timer started
                if @generation == current_gen && @pending
                  if @trailing
                    args_to_use = @last_args
                    @pending = false
                    @last_args = nil
                    @called_leading = false
                    execute(args_to_use)
                  else
                    @pending = false
                    @called_leading = false
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
        end
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
          end
        end

        execute(args) if should_execute
      end

      # Whether there is a pending execution.
      #
      # @return [Boolean]
      def pending?
        @mutex.synchronize { @pending }
      end

      private

      def execute(args)
        @block.call(*args)
      rescue StandardError
        # Swallow errors in the callback to avoid killing timer threads
        nil
      end
    end
  end
end
