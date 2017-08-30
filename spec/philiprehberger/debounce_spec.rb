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
