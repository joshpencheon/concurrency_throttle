# frozen_string_literal: true

require_relative "concurrency_throttle/version"

class ConcurrencyThrottle
  class ThrottleError < StandardError; end

  def initialize(connection:, name:, concurrency: 1, duration: 0)
    @connection = connection
    @name = name
    @concurrency = concurrency
    @duration = duration
  end

  def limit(timeout: nil, &block)
    with_concurrency_lock(timeout) do
      holding_for_duration { yield }
    end
  end

  private

  attr_reader :connection, :name, :concurrency, :duration

  def with_concurrency_lock(timeout, &block)
    shuffled_ids = lock_ids.shuffle
    wait_for_id = shuffled_ids.pop if timeout

    got_lock_id = shuffled_ids.detect { connection.get_advisory_lock(it) }
    if !got_lock_id && wait_for_id && connection.get_advisory_lock(wait_for_id, timeout)
      got_lock_id = wait_for_id
    end

    raise(ThrottleError, "unable to acquire throttle slot: #{name}") unless got_lock_id

    begin
      yield
    ensure
      connection.release_advisory_lock(got_lock_id)
    end
  end

  def lock_ids
    @lock_ids ||= concurrency.times.map do |index|
      "concurrency-throttle:#{name}:#{concurrency}:#{index}"
    end
  end

  def holding_for_duration(&block)
    now = Time.now
    result = nil
    begin
      result = yield
    ensure
      elapsed = Time.now - now
      sleep [duration - elapsed, 0].max
    end
    result
  end
end
