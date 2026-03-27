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
