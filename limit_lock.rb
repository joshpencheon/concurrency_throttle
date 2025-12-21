require "bundler/setup"
require "active_record"

class LimitLock
  class LockAcquisitionFailed < StandardError; end

  def initialize(connection:, name:, concurrency: 1, duration: 0)
    @connection = connection
    @name = name
    @concurrency = concurrency
    @duration = duration
  end

  def try_lock(timeout: nil, &block)
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

    raise(LockAcquisitionFailed, "unable to get LimitLock: #{name}") unless got_lock_id

    begin
      yield
    ensure
      connection.release_advisory_lock(got_lock_id)
    end
  end

  def lock_ids
    @lock_ids ||= concurrency.times.map do |index|
      "limit-lock:#{name}:#{concurrency}:#{index}"
    end
  end

  def holding_for_duration(&block)
    now = Time.now
    result = yield
    elapsed = Time.now - now

    sleep [duration - elapsed, 0].max

    result
  end
end

def in_threads(count)
  count.times.map do |n|
    Thread.new { yield n }
  end.each(&:join)
end

def time
  threads = 10
  concurrency = 5
  duration = 0.1
  # timeout = 3
  timeout = false
  total = 50
  work = (1..total).to_a

  now = Time.now
  yield threads, concurrency, duration, timeout, work
  elapsed = Time.now - now

  puts <<~SUMMARY

    Completed #{total} across #{threads} threads in #{elapsed.round(2)} seconds
      - target: #{(concurrency / duration.to_f).round(2)}
      - actual: #{(total/elapsed).round(2)} / sec
  SUMMARY
end

ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     "localhost",
  username: "root",
  password: "",
  pool: 10,
)


time do |threads, concurrency, duration, timeout, work|
  in_threads(threads) do |n|
    lock = LimitLock.new(
      connection: ActiveRecord::Base.connection,
      name: "testing",
      concurrency:,
      duration:
    )

    loop do
      break unless lock.try_lock(timeout:) do
        if item = work.pop
          print "#{n}. "
          item
        end
      end
    end
  rescue LimitLock::LockAcquisitionFailed => e
    print "#{n}! "
  end
end
