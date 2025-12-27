require "bundler/setup"
require "active_record"

require_relative "lib/limit_lock"

ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     "localhost",
  username: "root",
  password: "",
  pool: 10,
)

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
