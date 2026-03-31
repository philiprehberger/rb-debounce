# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Sliding window rate limiter.
    class RateLimiter
      def initialize(limit:, window:)
        raise ArgumentError, 'Limit must be a positive integer' unless limit.is_a?(Integer) && limit.positive?
        raise ArgumentError, 'Window must be a positive number' unless window.is_a?(Numeric) && window.positive?

        @limit = limit
        @window = window
        @requests = Hash.new { |h, k| h[k] = [] }
        @mutex = Mutex.new
      end

      def call(key = :default)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        @mutex.synchronize do
          cleanup!(key, now)
          remaining = @limit - @requests[key].length

          if remaining.positive?
            @requests[key] << now
            { allowed: true, remaining: remaining - 1, retry_after: 0 }
          else
            oldest = @requests[key].first
            retry_after = oldest + @window - now
            { allowed: false, remaining: 0, retry_after: [retry_after, 0].max }
          end
        end
      end

      def reset(key = :default)
        @mutex.synchronize { @requests.delete(key) }
        self
      end

      private

      def cleanup!(key, now)
        @requests[key].reject! { |t| t < now - @window }
      end
    end
  end
end
