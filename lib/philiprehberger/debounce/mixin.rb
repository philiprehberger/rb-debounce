# frozen_string_literal: true

module Philiprehberger
  module Debounce
    # Mixin providing class-level macros to debounce or throttle instance methods.
    #
    # @example
    #   class SearchController
    #     include Philiprehberger::Debounce::Mixin
    #
    #     def search(query)
    #       # expensive search
    #     end
    #     debounce_method :search, wait: 0.5
    #
    #     def log_event(event)
    #       # logging
    #     end
    #     throttle_method :log_event, interval: 1.0
    #   end
    module Mixin
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Class-level macros for debouncing and throttling methods.
      module ClassMethods
        # Wraps an instance method so that calls are debounced.
        #
        # The original method is renamed and a new method is created that
        # delegates to a {Debouncer} instance stored on the object.
        #
        # @param method_name [Symbol] the method to debounce
        # @param wait [Float] delay in seconds
        # @param leading [Boolean] fire on the leading edge
        # @param trailing [Boolean] fire on the trailing edge
        # @return [void]
        def debounce_method(method_name, wait:, leading: false, trailing: true)
          original = :"_undebounced_#{method_name}"
          alias_method original, method_name

          define_method(method_name) do |*args|
            @_debouncers ||= {}
            @_debouncers[method_name] ||= Debouncer.new(
              wait: wait, leading: leading, trailing: trailing
            ) { |*a| send(original, *a) }

            @_debouncers[method_name].call(*args)
          end
        end

        # Wraps an instance method so that calls are throttled.
        #
        # The original method is renamed and a new method is created that
        # delegates to a {Throttler} instance stored on the object.
        #
        # @param method_name [Symbol] the method to throttle
        # @param interval [Float] minimum time between executions in seconds
        # @param leading [Boolean] fire on the leading edge
        # @param trailing [Boolean] fire on the trailing edge
        # @return [void]
        def throttle_method(method_name, interval:, leading: true, trailing: false)
          original = :"_unthrottled_#{method_name}"
          alias_method original, method_name

          define_method(method_name) do |*args|
            @_throttlers ||= {}
            @_throttlers[method_name] ||= Throttler.new(
              interval: interval, leading: leading, trailing: trailing
            ) { |*a| send(original, *a) }

            @_throttlers[method_name].call(*args)
          end
        end
      end
    end
  end
end
