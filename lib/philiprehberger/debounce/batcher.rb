# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Buffer items and flush in size-or-time-triggered batches.
    #
    # Items are pushed via {#<<} or {#push}. The block is invoked with the
    # buffered array when either:
    #
    # - the buffer has accumulated `size` items, or
    # - `max_wait` seconds have elapsed since the first buffered item.
    #
    # The block always receives a non-empty Array. Manual {#flush} forces an
    # immediate invocation of any pending items; {#cancel} discards them
    # without invoking the block.
    class Batcher
      def initialize(size:, max_wait:, on_error: nil, &block)
        raise ArgumentError, 'Block is required' unless block
        raise ArgumentError, 'Size must be a positive Integer' unless size.is_a?(Integer) && size.positive?
        raise ArgumentError, 'max_wait must be a positive Numeric' unless max_wait.is_a?(Numeric) && max_wait.positive?

        @size = size
        @max_wait = max_wait
        @block = block
        @on_error = on_error
        @queue = []
        @mutex = Mutex.new
        @timer_thread = nil
        @generation = 0
      end

      # Add an item to the batch. Triggers a size-flush when full,
      # otherwise starts a max_wait timer on the first buffered item.
      #
      # @param item [Object] the item to buffer
      # @return [self]
      def <<(item)
        push(item)
      end

      def push(item)
        items = nil
        @mutex.synchronize do
          @queue << item
          if @queue.length >= @size
            items = @queue.dup
            @queue.clear
            @generation += 1
          elsif @queue.length == 1
            @generation += 1
            schedule_flush(@generation)
          end
        end
        invoke_block(items) if items
        self
      end

      # Force an immediate flush of pending items.
      # @return [void]
      def flush
        items = nil
        @mutex.synchronize do
          return if @queue.empty?

          items = @queue.dup
          @queue.clear
          @generation += 1
        end
        invoke_block(items)
      end

      # Discard pending items without invoking the block.
      # @return [void]
      def cancel
        @mutex.synchronize do
          @queue.clear
          @generation += 1
        end
      end

      # Number of items currently buffered.
      # @return [Integer]
      def pending
        @mutex.synchronize { @queue.length }
      end

      # Snapshot of the current buffered items.
      # @return [Array]
      def pending_items
        @mutex.synchronize { @queue.dup }
      end

      private

      def schedule_flush(gen)
        @timer_thread = Thread.new do
          sleep(@max_wait)
          items = nil
          @mutex.synchronize do
            next unless @generation == gen
            next if @queue.empty?

            items = @queue.dup
            @queue.clear
          end
          invoke_block(items) if items
        end
      end

      def invoke_block(items)
        @block.call(items)
      rescue StandardError => e
        return unless @on_error

        begin
          @on_error.call(e)
        rescue StandardError
          nil
        end
      end
    end
  end
end
