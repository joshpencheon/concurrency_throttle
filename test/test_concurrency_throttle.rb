# frozen_string_literal: true

require "minitest/autorun"
require "active_record"

require_relative "../lib/concurrency_throttle"

# Setup ActiveRecord connection to MySQL test database
ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     "localhost",
  username: "root",
  password: "",
)

class ConcurrencyThrottleTest < Minitest::Test
  def test_try_lock_success
    lock = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 1, duration: 0.2)

    assert_elapsed(0.2) do
      yielded = false
      lock.try_lock { yielded = true }

      assert yielded
    end
  end

  def test_try_lock_with_exception
    lock = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 1, duration: 0.2)

    assert_raises("error once locked") do
      assert_elapsed(0.2, "should still hold the lock for the minimum duration") do
        lock.try_lock { raise "error once locked" }
      end
    end
  end

  def test_try_lock_success_with_concurrency
    with_existing_advisory_lock("concurrency-throttle:foo:1:0") do
      lock = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 2, duration: 0.2)

      assert_elapsed(0.2) do
        yielded = false
        lock.try_lock { yielded = true }

        assert yielded
      end
    end
  end

  def test_try_lock_failure_without_concurrency
    with_existing_advisory_lock("concurrency-throttle:foo:1:0") do
      lock = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 1, duration: 0.2)

      assert_elapsed_less_than(0.01, "should have raised immediately") do
        assert_raises(ConcurrencyThrottle::ThrottleError) do
          lock.try_lock { }
        end
      end
    end
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def with_existing_advisory_lock(name)
    other_connection = nil
    Thread.new { other_connection = ActiveRecord::Base.connection }.join
    other_connection.get_advisory_lock(name)

    yield
  ensure
    other_connection.release_advisory_lock("concurrency-throttle:foo:1:0")
  end

  def assert_elapsed(duration, message = nil, &block)
    started = Time.now
    yield
    elapsed = Time.now - started

    assert_in_delta duration, elapsed, elapsed * 0.05, message
  end

  def assert_elapsed_less_than(maximum, message = nil, &block)
    started = Time.now
    yield
    elapsed = Time.now - started

    assert_operator elapsed, :<, maximum, message
  end
end
