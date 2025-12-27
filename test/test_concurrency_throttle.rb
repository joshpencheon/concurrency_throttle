# frozen_string_literal: true

require "minitest/autorun"
require "active_record"

require_relative "../lib/concurrency_throttle"

# Setup ActiveRecord connection to MySQL test database
ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     ENV.fetch("MYSQL_HOST", "localhost"),
  username: "root",
  password: "",
)

class ConcurrencyThrottleTest < Minitest::Test
  def test_limit_success
    throttle = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 1, duration: 0.2)

    assert_elapsed_at_least(0.2) do
      yielded = false
      throttle.limit { yielded = true }

      assert yielded
    end
  end

  def test_limit_with_exception
    throttle = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 1, duration: 0.2)

    assert_raises("error once locked") do
      assert_elapsed_at_least(0.2, "should still hold the lock for the minimum duration") do
        throttle.limit { raise "error once locked" }
      end
    end
  end

  def test_limit_success_with_concurrency
    with_existing_advisory_lock("concurrency-throttle:foo:1:0") do
      throttle = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 2, duration: 0.2)

      assert_elapsed_at_least(0.2) do
        yielded = false
        throttle.limit { yielded = true }

        assert yielded
      end
    end
  end

  def test_limit_failure_without_concurrency
    with_existing_advisory_lock("concurrency-throttle:foo:1:0") do
      throttle = ConcurrencyThrottle.new(connection:, name: "foo", concurrency: 1, duration: 0.2)

      assert_elapsed_less_than(0.1, "should have raised immediately") do
        assert_raises(ConcurrencyThrottle::ThrottleError) do
          throttle.limit { }
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

  def assert_elapsed(operator, target, message = nil, &block)
    started = Time.now
    yield
    elapsed = Time.now - started

    assert_operator elapsed, operator, target, message
  end

  def assert_elapsed_less_than(minimum, message = nil, &block)
    assert_elapsed(:<, minimum, message, &block)
  end

  def assert_elapsed_at_least(maximum, message = nil, &block)
    assert_elapsed(:>=, maximum, message, &block)
  end
end
