import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

nonisolated(unsafe) var totalTests = 0
nonisolated(unsafe) var failedTests = 0

func suite(_ name: String, _ body: () -> Void) {
    print("\n\(name)")
    body()
}

func test(_ name: String, _ body: () throws -> Void) {
    totalTests += 1
    do {
        try body()
        print("  ✓ \(name)")
    } catch {
        failedTests += 1
        print("  ✗ \(name): \(error)")
    }
}

func expect<T: Equatable>(_ actual: T, _ expected: T, file: String = #file, line: Int = #line) throws {
    guard actual == expected else {
        throw TestFailure(description: "expected \(expected), got \(actual) (\(file):\(line))")
    }
}

func expect(_ condition: Bool, _ message: String = "condition was false", file: String = #file, line: Int = #line) throws {
    guard condition else {
        throw TestFailure(description: "\(message) (\(file):\(line))")
    }
}

func reportResults() {
    print("\n\(totalTests) tests, \(failedTests) failed")
    if failedTests > 0 {
        exit(1)
    }
}
