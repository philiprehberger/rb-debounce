# frozen_string_literal: true

require_relative 'debounce/version'
require_relative 'debounce/debouncer'
require_relative 'debounce/throttler'
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
    # @yield [*args] the block to execute after the debounce period
    # @return [Debouncer]
    def self.debounce(wait:, leading: false, trailing: true, &block)
      Debouncer.new(wait: wait, leading: leading, trailing: trailing, &block)
    end

    # Create a new throttler that limits execution to at most once per interval.
    #
    # @param interval [Float] minimum time between executions in seconds
    # @param leading [Boolean] fire on the leading edge (default: true)
    # @param trailing [Boolean] fire on the trailing edge (default: false)
    # @yield [*args] the block to execute
    # @return [Throttler]
    def self.throttle(interval:, leading: true, trailing: false, &block)
      Throttler.new(interval: interval, leading: leading, trailing: trailing, &block)
    end
  end
end
