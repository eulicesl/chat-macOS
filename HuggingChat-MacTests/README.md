# HuggingChat-Mac Test Suite

This directory contains unit tests for the HuggingChat-Mac application.

## Running Tests

### Using Xcode
1. Open `HuggingChat-Mac.xcodeproj` in Xcode
2. Press `Cmd + U` to run all tests
3. Or use the Test Navigator (`Cmd + 6`) to run specific tests

### Using Command Line
```bash
xcodebuild test -scheme HuggingChat-Mac -destination 'platform=macOS'
```

## Test Coverage

### KeychainServiceTests (15 tests)
Tests for secure credential storage:
- Basic CRUD operations (save, retrieve, delete)
- Multiple key management
- Edge cases (empty strings, long strings, special characters)
- Performance benchmarks

### UserAgentBuilderTests (16 tests)
Tests for user agent generation:
- User agent string format and content
- System information extraction
- Consistency across calls
- Performance benchmarks

### AppLoggerTests (23 tests)
Tests for structured logging:
- All logger categories (network, auth, audio, etc.)
- Log levels (debug, info, warning, error, critical)
- Specialized logging methods
- Edge cases and performance

## Total Test Count: 54 Tests

**Note on Test Counting:**
- Each `func test...()` method counts as one test
- Performance tests using `measure {}` blocks count as individual tests
- Example: `testLoggerPerformance()` with a `measure {}` block = 1 test
- The 54 total includes all test methods across all test files
- Test breakdown: 15 (Keychain) + 16 (UserAgent) + 23 (AppLogger) = 54 tests

## Code Coverage Goals

- **Target:** 60% overall code coverage
- **Critical Services:** 80%+ coverage
  - KeychainService: 90%+
  - AppLogger: 85%+
  - UserAgentBuilder: 80%+

## Adding New Tests

1. Create a new test file in `HuggingChat-MacTests/`
2. Import XCTest and the main app module:
   ```swift
   import XCTest
   @testable import HuggingChat_Mac
   ```
3. Follow the naming convention: `[ClassName]Tests.swift`
4. Use descriptive test names: `test[MethodName][Scenario][ExpectedResult]`

## Test Categories

### Unit Tests
- Individual component testing
- No external dependencies
- Fast execution (< 0.1s per test)

### Integration Tests
- Component interaction testing
- May use mocks for external services
- Medium execution time (< 1s per test)

### Performance Tests
- Benchmark critical operations
- Use `measure {}` blocks
- Baseline comparisons for regressions

## Continuous Integration

Tests are automatically run on:
- Pull requests
- Commits to main branch
- Release tags

## Best Practices

1. **Test Independence:** Each test should be independent and can run in any order
2. **Setup/Teardown:** Use `setUp()` and `tearDown()` for test fixtures
3. **Assertions:** Use descriptive assertion messages
4. **Coverage:** Aim for 100% coverage of public APIs
5. **Performance:** Keep tests fast (avoid sleeps, use mocks)

## Mocking

For services with external dependencies:
- Network calls: Use URLProtocol mocking
- File system: Use temporary directories
- Keychain: Clean up in tearDown

## Debugging Failed Tests

1. Run individual test: Click the diamond icon next to the test
2. Add breakpoints in test or source code
3. Check Console output for AppLogger messages
4. Use `print()` or `debugPrint()` for temporary debugging

## Test Reports

Test reports are generated in:
- Xcode: Result Bundle (`.xcresult`)
- CI: JUnit XML format for dashboard integration
