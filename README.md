# ConcurrencyThrottle

[![CI](https://github.com/joshpencheon/limit_locks/workflows/CI/badge.svg)](https://github.com/joshpencheon/limit_locks/actions)

An experimental implementation of using MySQL advisory locks for cooperative rate-limited processing.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'concurrency_throttle'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install concurrency_throttle
```

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
result = throttle.limit { make_api_call }
# => result, or raises ConcurrencyThrottle::ThrottleError

# Waits up to 5 seconds before raising if concurrency limit is already reached:
result = throttle.limit(timeout: 5) { make_api_call }
# => result, or raises ConcurrencyThrottle::ThrottleError
```

## Development

To run the tests:

```
bundle exec rake
```
