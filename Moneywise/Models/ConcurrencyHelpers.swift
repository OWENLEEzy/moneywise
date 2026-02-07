import Foundation

/// A simple cancellation token for cooperative cancellation of async operations
struct CancellationToken {
    private var isCancelled = false

    /// Marks the token as cancelled
    mutating func cancel() {
        isCancelled = true
    }

    /// Checks if the operation has been cancelled and throws if so
    /// - Throws: `CancellationError` if the token has been cancelled
    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    /// Returns whether cancellation has been requested
    var isCancelling: Bool { isCancelled }
}

/// An error thrown when a cancellation token is checked after being cancelled
struct CancellationError: Error {
    var localizedDescription: String {
        "Operation was cancelled"
    }
}
