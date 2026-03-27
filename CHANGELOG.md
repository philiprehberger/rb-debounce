# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
