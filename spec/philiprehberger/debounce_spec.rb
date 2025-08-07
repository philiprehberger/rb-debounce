# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Debounce do
  it 'has a version number' do
    expect(Philiprehberger::Debounce::VERSION).not_to be_nil
  end

  describe '.debounce' do
    it 'returns a Debouncer' do
      d = described_class.debounce(wait: 0.1) { nil }
      expect(d).to be_a(Philiprehberger::Debounce::Debouncer)
    end
  end

  describe '.throttle' do
    it 'returns a Throttler' do
      t = described_class.throttle(interval: 0.1) { nil }
      expect(t).to be_a(Philiprehberger::Debounce::Throttler)
    end
  end

  describe '.keyed' do
    it 'returns a KeyedDebouncer' do
      k = described_class.keyed(wait: 0.1) { nil }
      expect(k).to be_a(Philiprehberger::Debounce::KeyedDebouncer)
    end
  end

  describe '.rate_limiter' do
    it 'returns a RateLimiter' do
      rl = described_class.rate_limiter(limit: 5, window: 1.0)
      expect(rl).to be_a(Philiprehberger::Debounce::RateLimiter)
    end
  end

  describe '.coalesce' do
    it 'returns a Coalescer' do
      c = described_class.coalesce(wait: 0.1) { nil }
      expect(c).to be_a(Philiprehberger::Debounce::Coalescer)
    end
  end

  describe 'on_error callback' do
    it 'reports debouncer block errors via on_error' do
      errors = []
      debouncer = described_class.debounce(wait: 0.05, on_error: ->(e) { errors << e }) { raise 'boom' }
      debouncer.call
      sleep 0.15
      expect(errors.size).to eq(1)
      expect(errors.first.message).to eq('boom')
    end

    it 'reports throttler block errors via on_error' do
      errors = []
      throttler = described_class.throttle(interval: 0.05, on_error: ->(e) { errors << e }) { raise 'nope' }
      throttler.call
      expect(errors.map(&:message)).to eq(['nope'])
    end

    it 'reports coalescer block errors via on_error' do
      errors = []
      coalescer = described_class.coalesce(wait: 0.05, on_error: ->(e) { errors << e }) { raise 'bad' }
      coalescer.call('x')
      sleep 0.15
      expect(errors.map(&:message)).to eq(['bad'])
    end

    it 'swallows errors raised inside on_error itself' do
      debouncer = described_class.debounce(wait: 0.05, on_error: ->(_) { raise 'reporter exploded' }) { raise 'boom' }
      expect do
        debouncer.call
        sleep 0.15
      end.not_to raise_error
    end

    it 'does not leak errors when on_error is not provided' do
      debouncer = described_class.debounce(wait: 0.05) { raise 'boom' }
      expect do
        debouncer.call
        sleep 0.15
      end.not_to raise_error
    end
  end
end

RSpec.describe Philiprehberger::Debounce::Debouncer do
  describe 'trailing mode (default)' do
    it 'delays execution until the wait period elapses' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { |v| results << v }

      debouncer.call('a')
      expect(results).to be_empty

      sleep 0.15
      expect(results).to eq(['a'])
    end

    it 'only executes once for multiple rapid calls' do
      count = 0
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { count += 1 }

      5.times { debouncer.call }
      sleep 0.05
      5.times { debouncer.call }

      sleep 0.15
      expect(count).to eq(1)
    end

    it 'uses the arguments from the last call' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { |v| results << v }

      debouncer.call('first')
      debouncer.call('second')
      debouncer.call('third')

      sleep 0.15
      expect(results).to eq(['third'])
    end
  end

  describe '#cancel' do
    it 'prevents pending execution' do
      count = 0
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { count += 1 }

      debouncer.call
      debouncer.cancel

      sleep 0.15
      expect(count).to eq(0)
    end
  end

  describe '#flush' do
    it 'executes immediately if pending' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { |v| results << v }

      debouncer.call('flushed')
      debouncer.flush

      expect(results).to eq(['flushed'])
    end

    it 'does nothing if not pending' do
      count = 0
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { count += 1 }

      debouncer.flush
      expect(count).to eq(0)
    end
  end

  describe '#pending?' do
    it 'returns true when a call is pending' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { nil }

      expect(debouncer.pending?).to be false
      debouncer.call
      expect(debouncer.pending?).to be true
    end
  end

  describe 'leading mode' do
    it 'fires immediately on the first call' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.2, leading: true, trailing: false) { |v| results << v }

      debouncer.call('first')
      expect(results).to eq(['first'])

      debouncer.call('second')
      expect(results).to eq(['first'])
    end
  end

  describe 'leading and trailing mode' do
    it 'fires on both edges' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1, leading: true, trailing: true) { |v| results << v }

      debouncer.call('first')
      expect(results).to eq(['first'])

      debouncer.call('second')
      sleep 0.15
      expect(results).to eq(%w[first second])
    end
  end

  describe 'validation' do
    it 'raises without a block' do
      expect { Philiprehberger::Debounce.debounce(wait: 0.1) }.to raise_error(ArgumentError, /block/)
    end

    it 'raises with non-positive wait' do
      expect { Philiprehberger::Debounce.debounce(wait: 0) { nil } }.to raise_error(ArgumentError, /positive/)
    end

    it 'raises when both leading and trailing are false' do
      expect do
        Philiprehberger::Debounce.debounce(wait: 0.1, leading: false, trailing: false) { nil }
      end.to raise_error(ArgumentError, /leading or trailing/)
    end

    it 'raises with non-positive max_wait' do
      expect do
        Philiprehberger::Debounce.debounce(wait: 0.1, max_wait: 0) { nil }
      end.to raise_error(ArgumentError, /max_wait must be positive/)
    end
  end

  describe 'execution callbacks' do
    it 'calls on_execute after block runs' do
      callback_values = []
      debouncer = Philiprehberger::Debounce.debounce(
        wait: 0.1,
        on_execute: ->(result) { callback_values << result }, &:upcase
      )

      debouncer.call('hello')
      sleep 0.15
      expect(callback_values).to eq(['HELLO'])
    end

    it 'calls on_cancel when cancel is invoked' do
      cancelled = false
      debouncer = Philiprehberger::Debounce.debounce(
        wait: 1.0,
        on_cancel: -> { cancelled = true }
      ) { nil }

      debouncer.call
      debouncer.cancel
      expect(cancelled).to be true
    end

    it 'calls on_flush when flush is invoked' do
      flushed = false
      debouncer = Philiprehberger::Debounce.debounce(
        wait: 1.0,
        on_flush: -> { flushed = true }
      ) { nil }

      debouncer.call
      debouncer.flush
      expect(flushed).to be true
    end

    it 'calls on_flush even when nothing is pending' do
      flushed = false
      debouncer = Philiprehberger::Debounce.debounce(
        wait: 1.0,
        on_flush: -> { flushed = true }
      ) { nil }

      debouncer.flush
      expect(flushed).to be true
    end

    it 'works without callbacks' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { |v| results << v }

      debouncer.call('test')
      sleep 0.15
      expect(results).to eq(['test'])
    end
  end

  describe '#metrics' do
    it 'tracks call_count' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { nil }

      3.times { debouncer.call }
      expect(debouncer.metrics[:call_count]).to eq(3)
    end

    it 'tracks execution_count' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { nil }

      3.times { debouncer.call }
      sleep 0.15
      expect(debouncer.metrics[:execution_count]).to eq(1)
    end

    it 'computes suppressed_count' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { nil }

      5.times { debouncer.call }
      sleep 0.15
      m = debouncer.metrics
      expect(m[:suppressed_count]).to eq(m[:call_count] - m[:execution_count])
      expect(m[:suppressed_count]).to eq(4)
    end

    it 'counts leading edge executions' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.2, leading: true, trailing: false) { nil }

      debouncer.call
      expect(debouncer.metrics[:execution_count]).to eq(1)
    end
  end

  describe '#reset_metrics' do
    it 'resets all counters to zero' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1) { nil }

      3.times { debouncer.call }
      sleep 0.15
      debouncer.reset_metrics

      m = debouncer.metrics
      expect(m[:call_count]).to eq(0)
      expect(m[:execution_count]).to eq(0)
      expect(m[:suppressed_count]).to eq(0)
    end
  end

  describe 'max_wait' do
    it 'forces execution after max_wait even with continuous calls' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.2, max_wait: 0.3) { |v| results << v }

      debouncer.call('a')
      sleep 0.1
      debouncer.call('b')
      sleep 0.1
      debouncer.call('c')
      sleep 0.1
      debouncer.call('d')

      sleep 0.25
      expect(results).not_to be_empty
    end

    it 'behaves normally without max_wait' do
      results = []
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.15) { |v| results << v }

      debouncer.call('a')
      sleep 0.1
      debouncer.call('b')
      sleep 0.1
      debouncer.call('c')

      expect(results).to be_empty
      sleep 0.2
      expect(results).to eq(['c'])
    end

    it 'accepts nil max_wait for default behavior' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1, max_wait: nil) { nil }
      expect(debouncer).to be_a(Philiprehberger::Debounce::Debouncer)
    end
  end

  describe '#pending_args' do
    it 'returns nil when not pending' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { nil }
      expect(debouncer.pending_args).to be_nil
    end

    it 'returns the pending arguments' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { nil }

      debouncer.call('a', 'b')
      expect(debouncer.pending_args).to eq(%w[a b])
    end

    it 'returns the last call arguments' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { nil }

      debouncer.call('first')
      debouncer.call('second')
      expect(debouncer.pending_args).to eq(['second'])
    end

    it 'returns nil after flush' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { nil }

      debouncer.call('test')
      debouncer.flush
      expect(debouncer.pending_args).to be_nil
    end

    it 'returns nil after cancel' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 1.0) { nil }

      debouncer.call('test')
      debouncer.cancel
      expect(debouncer.pending_args).to be_nil
    end
  end
end

RSpec.describe Philiprehberger::Debounce::Debouncer do
  describe '#last_result' do
    it 'stores the last execution result' do
      debouncer = Philiprehberger::Debounce.debounce(wait: 0.1, &:upcase)

      expect(debouncer.last_result).to be_nil

      debouncer.call('hello')
      sleep 0.15
      expect(debouncer.last_result).to eq('HELLO')

      debouncer.call('world')
      sleep 0.15
      expect(debouncer.last_result).to eq('WORLD')
    end
  end
end

RSpec.describe Philiprehberger::Debounce::Throttler do
  describe '#last_result' do
    it 'stores the last execution result' do
      throttler = Philiprehberger::Debounce.throttle(interval: 0.1) { |v| v * 2 }

      expect(throttler.last_result).to be_nil

      throttler.call(5)
      expect(throttler.last_result).to eq(10)

      sleep 0.15
      throttler.call(7)
      expect(throttler.last_result).to eq(14)
    end
  end
end

RSpec.describe Philiprehberger::Debounce::RateLimiter do
  describe '#call' do
    it 'allows requests within limit' do
      limiter = Philiprehberger::Debounce.rate_limiter(limit: 3, window: 1.0)

      result = limiter.call
      expect(result[:allowed]).to be true
    end

    it 'blocks requests over limit' do
      limiter = Philiprehberger::Debounce.rate_limiter(limit: 2, window: 1.0)

      limiter.call
      limiter.call
      result = limiter.call
      expect(result[:allowed]).to be false
    end

    it 'returns remaining count' do
      limiter = Philiprehberger::Debounce.rate_limiter(limit: 3, window: 1.0)

      result1 = limiter.call
      expect(result1[:remaining]).to eq(2)

      result2 = limiter.call
      expect(result2[:remaining]).to eq(1)

      result3 = limiter.call
      expect(result3[:remaining]).to eq(0)
    end

    it 'returns retry_after when blocked' do
      limiter = Philiprehberger::Debounce.rate_limiter(limit: 1, window: 1.0)

      limiter.call
      result = limiter.call
      expect(result[:allowed]).to be false
      expect(result[:retry_after]).to be > 0
    end

    it 'allows new requests after window expires' do
      limiter = Philiprehberger::Debounce.rate_limiter(limit: 1, window: 0.1)

      limiter.call
      result_blocked = limiter.call
      expect(result_blocked[:allowed]).to be false

      sleep 0.15
      result_allowed = limiter.call
      expect(result_allowed[:allowed]).to be true
    end
  end

  describe '#reset' do
    it 'clears history for a key' do
      limiter = Philiprehberger::Debounce.rate_limiter(limit: 1, window: 1.0)

      limiter.call(:api)
      result_blocked = limiter.call(:api)
      expect(result_blocked[:allowed]).to be false

      limiter.reset(:api)
      result_after_reset = limiter.call(:api)
      expect(result_after_reset[:allowed]).to be true
    end
  end

  describe 'validation' do
    it 'raises for non-positive limit' do
      expect { Philiprehberger::Debounce.rate_limiter(limit: 0, window: 1.0) }.to raise_error(ArgumentError, /Limit/)
    end

    it 'raises for non-integer limit' do
      expect { Philiprehberger::Debounce.rate_limiter(limit: 1.5, window: 1.0) }.to raise_error(ArgumentError, /Limit/)
    end

    it 'raises for non-positive window' do
      expect { Philiprehberger::Debounce.rate_limiter(limit: 1, window: 0) }.to raise_error(ArgumentError, /Window/)
    end
  end
end

RSpec.describe Philiprehberger::Debounce::Coalescer do
  describe '#call' do
    it 'collects args and fires once after wait' do
      results = nil
      coalescer = Philiprehberger::Debounce.coalesce(wait: 0.1) { |items| results = items }

      coalescer.call('a')
      coalescer.call('b')
      coalescer.call('c')

      expect(results).to be_nil
      sleep 0.15
      expect(results).to eq([['a'], ['b'], ['c']])
    end
  end

  describe '#flush' do
    it 'fires immediately with queued args' do
      results = nil
      coalescer = Philiprehberger::Debounce.coalesce(wait: 1.0) { |items| results = items }

      coalescer.call('x')
      coalescer.call('y')
      coalescer.flush

      expect(results).to eq([['x'], ['y']])
    end
  end

  describe '#cancel' do
    it 'clears the queue' do
      results = nil
      coalescer = Philiprehberger::Debounce.coalesce(wait: 0.1) { |items| results = items }

      coalescer.call('a')
      coalescer.call('b')
      coalescer.cancel

      sleep 0.15
      expect(results).to be_nil
    end
  end

  describe '#pending_count' do
    it 'reflects queue size' do
      coalescer = Philiprehberger::Debounce.coalesce(wait: 1.0) { |_| nil }

      expect(coalescer.pending_count).to eq(0)

      coalescer.call('a')
      coalescer.call('b')
      expect(coalescer.pending_count).to eq(2)

      coalescer.cancel
      expect(coalescer.pending_count).to eq(0)
    end
  end

  describe 'validation' do
    it 'raises without a block' do
      expect { Philiprehberger::Debounce::Coalescer.new(wait: 0.1) }.to raise_error(ArgumentError, /Block/)
    end

    it 'raises for non-positive wait' do
      expect { Philiprehberger::Debounce.coalesce(wait: 0) { nil } }.to raise_error(ArgumentError, /Wait/)
    end
  end
end

RSpec.describe Philiprehberger::Debounce::Throttler do
  describe 'leading mode (default)' do
    it 'fires immediately on the first call' do
      results = []
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2) { |v| results << v }

      throttler.call('first')
      expect(results).to eq(['first'])
    end

    it 'limits execution rate' do
      count = 0
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2) { count += 1 }

      throttler.call
      throttler.call
      throttler.call
      expect(count).to eq(1)

      sleep 0.25
      throttler.call
      expect(count).to eq(2)
    end
  end

  describe 'trailing mode' do
    it 'fires after the interval elapses' do
      results = []
      throttler = Philiprehberger::Debounce.throttle(interval: 0.1, leading: false, trailing: true) { |v| results << v }

      throttler.call('a')
      expect(results).to be_empty

      sleep 0.15
      expect(results).to eq(['a'])
    end
  end

  describe '#cancel' do
    it 'prevents pending trailing execution' do
      count = 0
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2, leading: true, trailing: true) { count += 1 }

      throttler.call
      expect(count).to eq(1)

      throttler.call
      throttler.cancel

      sleep 0.25
      expect(count).to eq(1)
    end
  end

  describe '#flush' do
    it 'executes immediately if pending' do
      results = []
      throttler = Philiprehberger::Debounce.throttle(interval: 1.0, leading: false, trailing: true) { |v| results << v }

      throttler.call('flushed')
      throttler.flush

      expect(results).to eq(['flushed'])
    end
  end

  describe '#pending?' do
    it 'returns true when a trailing call is pending' do
      throttler = Philiprehberger::Debounce.throttle(interval: 1.0, leading: false, trailing: true) { nil }

      expect(throttler.pending?).to be false
      throttler.call
      expect(throttler.pending?).to be true
    end
  end

  describe 'validation' do
    it 'raises without a block' do
      expect { Philiprehberger::Debounce.throttle(interval: 0.1) }.to raise_error(ArgumentError, /block/)
    end

    it 'raises with non-positive interval' do
      expect { Philiprehberger::Debounce.throttle(interval: 0) { nil } }.to raise_error(ArgumentError, /positive/)
    end
  end

  describe 'execution callbacks' do
    it 'calls on_execute after block runs' do
      callback_values = []
      throttler = Philiprehberger::Debounce.throttle(
        interval: 0.1,
        on_execute: ->(result) { callback_values << result }, &:upcase
      )

      throttler.call('hello')
      expect(callback_values).to eq(['HELLO'])
    end

    it 'calls on_cancel when cancel is invoked' do
      cancelled = false
      throttler = Philiprehberger::Debounce.throttle(
        interval: 1.0,
        leading: false,
        trailing: true,
        on_cancel: -> { cancelled = true }
      ) { nil }

      throttler.call
      throttler.cancel
      expect(cancelled).to be true
    end

    it 'calls on_flush when flush is invoked' do
      flushed = false
      throttler = Philiprehberger::Debounce.throttle(
        interval: 1.0,
        leading: false,
        trailing: true,
        on_flush: -> { flushed = true }
      ) { nil }

      throttler.call
      throttler.flush
      expect(flushed).to be true
    end
  end

  describe '#metrics' do
    it 'tracks call_count' do
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2) { nil }

      3.times { throttler.call }
      expect(throttler.metrics[:call_count]).to eq(3)
    end

    it 'tracks execution_count for leading mode' do
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2) { nil }

      3.times { throttler.call }
      expect(throttler.metrics[:execution_count]).to eq(1)
    end

    it 'computes suppressed_count' do
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2) { nil }

      5.times { throttler.call }
      m = throttler.metrics
      expect(m[:suppressed_count]).to eq(4)
    end
  end

  describe '#reset_metrics' do
    it 'resets all counters to zero' do
      throttler = Philiprehberger::Debounce.throttle(interval: 0.2) { nil }

      3.times { throttler.call }
      throttler.reset_metrics

      m = throttler.metrics
      expect(m[:call_count]).to eq(0)
      expect(m[:execution_count]).to eq(0)
      expect(m[:suppressed_count]).to eq(0)
    end
  end

  describe '#pending_args' do
    it 'returns nil when not pending' do
      throttler = Philiprehberger::Debounce.throttle(interval: 1.0) { nil }
      expect(throttler.pending_args).to be_nil
    end

    it 'returns the pending arguments' do
      throttler = Philiprehberger::Debounce.throttle(interval: 1.0, leading: false, trailing: true) { nil }

      throttler.call('a', 'b')
      expect(throttler.pending_args).to eq(%w[a b])
    end

    it 'returns nil after flush' do
      throttler = Philiprehberger::Debounce.throttle(interval: 1.0, leading: false, trailing: true) { nil }

      throttler.call('test')
      throttler.flush
      expect(throttler.pending_args).to be_nil
    end

    it 'returns nil after cancel' do
      throttler = Philiprehberger::Debounce.throttle(interval: 1.0, leading: false, trailing: true) { nil }

      throttler.call('test')
      throttler.cancel
      expect(throttler.pending_args).to be_nil
    end
  end
end

RSpec.describe Philiprehberger::Debounce::KeyedDebouncer do
  describe '#call' do
    it 'debounces per key independently' do
      results = {}
      keyed = Philiprehberger::Debounce.keyed(wait: 0.1) { |v| results[v] = true }

      keyed.call(:a, 'a_val')
      keyed.call(:b, 'b_val')

      sleep 0.15
      expect(results).to eq({ 'a_val' => true, 'b_val' => true })
    end

    it 'reuses the same debouncer for the same key' do
      count = 0
      keyed = Philiprehberger::Debounce.keyed(wait: 0.1) { count += 1 }

      keyed.call(:a)
      keyed.call(:a)
      keyed.call(:a)

      sleep 0.15
      expect(count).to eq(1)
    end
  end

  describe '#cancel' do
    it 'cancels a specific key' do
      results = []
      keyed = Philiprehberger::Debounce.keyed(wait: 0.1) { |v| results << v }

      keyed.call(:a, 'a')
      keyed.call(:b, 'b')
      keyed.cancel(:a)

      sleep 0.15
      expect(results).to eq(['b'])
    end

    it 'does nothing for unknown keys' do
      keyed = Philiprehberger::Debounce.keyed(wait: 0.1) { nil }
      expect { keyed.cancel(:unknown) }.not_to raise_error
    end
  end

  describe '#cancel_all' do
    it 'cancels all pending executions' do
      results = []
      keyed = Philiprehberger::Debounce.keyed(wait: 0.1) { |v| results << v }

      keyed.call(:a, 'a')
      keyed.call(:b, 'b')
      keyed.cancel_all

      sleep 0.15
      expect(results).to be_empty
    end
  end

  describe '#pending_keys' do
    it 'returns keys with pending executions' do
      keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }

      keyed.call(:a)
      keyed.call(:b)
      expect(keyed.pending_keys).to contain_exactly(:a, :b)
    end

    it 'returns empty array when nothing is pending' do
      keyed = Philiprehberger::Debounce.keyed(wait: 0.1) { nil }
      expect(keyed.pending_keys).to be_empty
    end

    it 'excludes cancelled keys' do
      keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }

      keyed.call(:a)
      keyed.call(:b)
      keyed.cancel(:a)

      expect(keyed.pending_keys).to eq([:b])
    end
  end

  describe 'validation' do
    it 'raises without a block' do
      expect { Philiprehberger::Debounce.keyed(wait: 0.1) }.to raise_error(ArgumentError, /block/)
    end
  end

  describe 'with options' do
    it 'passes leading option to child debouncers' do
      results = []
      keyed = Philiprehberger::Debounce.keyed(wait: 0.2, leading: true, trailing: false) { |v| results << v }

      keyed.call(:a, 'immediate')
      expect(results).to eq(['immediate'])
    end
  end
end

RSpec.describe Philiprehberger::Debounce::Mixin do
  let(:klass) do
    Class.new do
      include Philiprehberger::Debounce::Mixin

      attr_reader :calls

      def initialize
        @calls = []
      end

      def save(value)
        @calls << value
      end
      debounce_method :save, wait: 0.1

      def log(value)
        @calls << value
      end
      throttle_method :log, interval: 0.2
    end
  end

  describe 'debounce_method' do
    it 'debounces the wrapped method' do
      obj = klass.new

      obj.save('a')
      obj.save('b')
      obj.save('c')

      sleep 0.15
      expect(obj.calls).to eq(['c'])
    end
  end

  describe 'throttle_method' do
    it 'throttles the wrapped method' do
      obj = klass.new

      obj.log('first')
      obj.log('second')
      obj.log('third')

      expect(obj.calls).to eq(['first'])
    end
  end
end

RSpec.describe Philiprehberger::Debounce::KeyedDebouncer, '#flush and #flush_all' do
  it 'flushes a specific key immediately' do
    results = []
    keyed = Philiprehberger::Debounce.keyed(wait: 5.0) { |v| results << v }
    keyed.call(:a, 'alpha')
    keyed.flush(:a)
    sleep 0.05
    expect(results).to eq(['alpha'])
  end

  it 'does nothing when flushing a key with no debouncer' do
    keyed = Philiprehberger::Debounce.keyed(wait: 5.0) { |v| v }
    expect { keyed.flush(:missing) }.not_to raise_error
  end

  it 'flushes all pending keys' do
    results = []
    keyed = Philiprehberger::Debounce.keyed(wait: 5.0) { |v| results << v }
    keyed.call(:a, 'alpha')
    keyed.call(:b, 'beta')
    keyed.flush_all
    sleep 0.05
    expect(results).to contain_exactly('alpha', 'beta')
  end

  it 'clears pending state after flush' do
    keyed = Philiprehberger::Debounce.keyed(wait: 5.0) { |v| v }
    keyed.call(:a, 'x')
    keyed.flush(:a)
    sleep 0.05
    expect(keyed.pending_keys).to be_empty
  end
end

RSpec.describe Philiprehberger::Debounce::KeyedDebouncer, '#size' do
  it 'returns 0 when empty' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }
    expect(keyed.size).to eq(0)
  end

  it 'returns 1 after a single call' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }
    keyed.call(:a)
    expect(keyed.size).to eq(1)
  end

  it 'returns N after calls with N distinct keys' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }
    keyed.call(:a)
    keyed.call(:b)
    keyed.call(:c)
    expect(keyed.size).to eq(3)
  end

  it 'does not grow when the same key is reused' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }
    keyed.call(:a)
    keyed.call(:a)
    keyed.call(:a)
    expect(keyed.size).to eq(1)
  end

  it 'decreases after cancel(key)' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }
    keyed.call(:a)
    keyed.call(:b)
    expect(keyed.size).to eq(2)
    keyed.cancel(:a)
    expect(keyed.size).to eq(1)
  end

  it 'returns 0 after cancel_all' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { nil }
    keyed.call(:a)
    keyed.call(:b)
    keyed.cancel_all
    expect(keyed.size).to eq(0)
  end

  it 'returns 0 after flush_all' do
    keyed = Philiprehberger::Debounce.keyed(wait: 5.0) { |v| v }
    keyed.call(:a, 'alpha')
    keyed.call(:b, 'beta')
    keyed.flush_all
    expect(keyed.size).to eq(0)
  end
end

RSpec.describe Philiprehberger::Debounce::KeyedDebouncer, 'auto-eviction after completion' do
  it 'removes the key from internal state after the block fires' do
    keyed = Philiprehberger::Debounce.keyed(wait: 0.05) { |v| v }
    keyed.call(:a, 'hello')
    expect(keyed.size).to eq(1)
    sleep 0.15
    expect(keyed.size).to eq(0)
  end

  it 'allows the same key to be reused after auto-eviction' do
    results = []
    keyed = Philiprehberger::Debounce.keyed(wait: 0.05) { |v| results << v }
    keyed.call(:a, 'first')
    sleep 0.15
    expect(results).to eq(['first'])
    expect(keyed.size).to eq(0)

    keyed.call(:a, 'second')
    sleep 0.15
    expect(results).to eq(%w[first second])
  end

  it 'still calls the user on_execute callback after auto-eviction' do
    executed = []
    keyed = Philiprehberger::Debounce.keyed(
      wait: 0.05,
      on_execute: ->(result) { executed << result }
    ) { |v| v.upcase.to_s }
    keyed.call(:a, 'hi')
    sleep 0.15
    expect(executed).to eq(['HI'])
    expect(keyed.size).to eq(0)
  end

  it 'does not evict keys that are still pending' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0) { |v| v }
    keyed.call(:a)
    keyed.call(:b)
    sleep 0.05
    expect(keyed.size).to eq(2)
    keyed.cancel_all
  end
end

RSpec.describe Philiprehberger::Debounce::KeyedDebouncer, 'max_keys:' do
  it 'evicts the oldest key when adding a new key would exceed max_keys' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0, max_keys: 2) { |v| v }
    keyed.call(:a)
    keyed.call(:b)
    expect(keyed.size).to eq(2)

    keyed.call(:c)
    expect(keyed.size).to eq(2)
    expect(keyed.pending_keys).not_to include(:a)
    expect(keyed.pending_keys).to include(:b, :c)
    keyed.cancel_all
  end

  it 'evicts the second-oldest key after the first has been evicted' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0, max_keys: 2) { |v| v }
    keyed.call(:a)
    keyed.call(:b)
    keyed.call(:c)
    expect(keyed.pending_keys).not_to include(:a)

    keyed.call(:d)
    expect(keyed.pending_keys).not_to include(:b)
    expect(keyed.pending_keys).to include(:c, :d)
    keyed.cancel_all
  end

  it 'does not evict when under the limit' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0, max_keys: 3) { |v| v }
    keyed.call(:a)
    keyed.call(:b)
    expect(keyed.size).to eq(2)
    expect(keyed.pending_keys).to include(:a, :b)
    keyed.cancel_all
  end

  it 'does not evict when the same key is reused' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0, max_keys: 1) { |v| v }
    keyed.call(:a)
    keyed.call(:a)
    keyed.call(:a)
    expect(keyed.size).to eq(1)
    expect(keyed.pending_keys).to include(:a)
    keyed.cancel_all
  end

  it 'raises ArgumentError for non-positive max_keys' do
    expect do
      Philiprehberger::Debounce.keyed(wait: 0.1, max_keys: 0) { nil }
    end.to raise_error(ArgumentError, /max_keys/)
  end

  it 'raises ArgumentError for non-integer max_keys' do
    expect do
      Philiprehberger::Debounce.keyed(wait: 0.1, max_keys: 2.5) { nil }
    end.to raise_error(ArgumentError, /max_keys/)
  end

  it 'accepts nil max_keys for unlimited keys' do
    keyed = Philiprehberger::Debounce.keyed(wait: 1.0, max_keys: nil) { |v| v }
    expect(keyed).to be_a(Philiprehberger::Debounce::KeyedDebouncer)
    keyed.cancel_all
  end
end

RSpec.describe Philiprehberger::Debounce::Coalescer, '#pending_args' do
  it 'returns empty array when nothing is queued' do
    coalescer = Philiprehberger::Debounce.coalesce(wait: 5.0) { |batch| batch }
    expect(coalescer.pending_args).to eq([])
  end

  it 'returns a snapshot of queued argument arrays' do
    coalescer = Philiprehberger::Debounce.coalesce(wait: 5.0) { |batch| batch }
    coalescer.call('a', 1)
    coalescer.call('b', 2)
    expect(coalescer.pending_args).to eq([['a', 1], ['b', 2]])
  end

  it 'returns empty after flush' do
    coalescer = Philiprehberger::Debounce.coalesce(wait: 5.0) { |batch| batch }
    coalescer.call('a')
    coalescer.flush
    expect(coalescer.pending_args).to eq([])
  end

  it 'returns a copy that does not affect internal state' do
    coalescer = Philiprehberger::Debounce.coalesce(wait: 5.0) { |batch| batch }
    coalescer.call('a')
    snapshot = coalescer.pending_args
    snapshot.clear
    expect(coalescer.pending_args).to eq([['a']])
  end
end
