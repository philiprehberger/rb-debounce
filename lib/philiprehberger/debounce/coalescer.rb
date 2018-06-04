# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Collects arguments from multiple calls and passes them as an array
    # to a single block invocation after the wait period.
    class Coalescer
      def initialize(wait:, &block)
        raise ArgumentError, 'Block is required' unless block
        raise ArgumentError, 'Wait must be a positive number' unless wait.is_a?(Numeric) && wait.positive?

        @wait = wait
        @block = block
        @queue = []
        @mutex = Mutex.new
        @timer = nil
        @generation = 0
      end

      def call(*args)
        @mutex.synchronize do
          @queue << args
          @generation += 1
          schedule_flush(@generation)
        end
      end

      def flush
        items = nil
        @mutex.synchronize do
          return if @queue.empty?

          items = @queue.dup
          @queue.clear
          @generation += 1
        end
        @block.call(items) if items && !items.empty?
      end

      def cancel
        @mutex.synchronize do
          @queue.clear
          @generation += 1
        end
      end

      def pending_count
        @mutex.synchronize { @queue.length }
      end

      private

      def schedule_flush(gen)
        Thread.new do
          sleep(@wait)
          items = nil
          @mutex.synchronize do
            next unless @generation == gen

            items = @queue.dup
            @queue.clear
          end
          @block.call(items) if items && !items.empty?
        end
      end
    end
  end
end
