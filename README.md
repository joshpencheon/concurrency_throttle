# ConcurrencyThrottle

An experimental implementation of using MySQL advisory locks for cooperative rate-limited processing.

## Usage

```ruby
connection = ActiveRecord::Base.connection

throttle = ConcurrencyThrottle.new(
  connection:,

  # Namespace/scope of the collaborative lock:
  name: "api-calls",

  # E.g. max 5 runs per 3 seconds:
  concurrency: 5,
  duration: 3
)

# Raises an exception immediately if concurrency limit is already reached:
result = throttle.try_lock { make_api_call }
# => result, or raises ConcurrencyThrottle::ThrottleError

# Waits up to 5 seconds before raising if concurrency limit is already reached:
result = throttle.try_lock(timeout: 5) { make_api_call }
# => result, or raises ConcurrencyThrottle::ThrottleError
```

## Development

To run the tests:

```
bundle exec rake
```

## TODO

Here's a list of things that would be nice to achieve:

-[x] pick a better name for the module and public API (around "throttling").
-[ ] [package as a ruby gem]
-[ ] Add GitHub Actions for testing.
