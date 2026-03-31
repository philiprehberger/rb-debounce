# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-03-31

### Added

- `Debounce.rate_limiter(limit:, window:)` for sliding window rate limiting
- `Debounce.coalesce(wait:, &block)` for batching arguments into single invocation
- `Debouncer#last_result` and `Throttler#last_result` for retrieving last execution return value

## [0.2.0] - 2026-03-28

### Added

- Execution callbacks: `on_execute:`, `on_cancel:`, `on_flush:` for lifecycle observability
- `#metrics` returning call_count, execution_count, suppressed_count
- `max_wait:` option for debouncer to force execution after maximum wait time
- `Debounce.keyed(wait:, &block)` for per-key debouncing
- `#pending_args` for inspecting queued arguments before flush/cancel

## [0.1.1] - 2026-03-26

### Added

- Add GitHub funding configuration

## [0.1.0] - 2026-03-26

### Added
- Initial release
- `Debouncer` class with leading/trailing edge support
- `Throttler` class with leading/trailing edge support
- `cancel` and `flush` control methods
- `Mixin` module with `debounce_method` and `throttle_method` class macros
- Thread-safe implementation using Mutex and ConditionVariable
