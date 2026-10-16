import Foundation

/// An error shown to the user. The message says what to do next.
struct ScreenInkError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }

    static func cannotWrite(_ url: URL) -> ScreenInkError {
        ScreenInkError("Cannot write \(url.path). Check free disk space and that ~/ScreenInk is writable.")
    }
}
