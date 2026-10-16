import Foundation

/// An error shown to the user. The message says what to do next.
struct PromptCastError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }

    static func cannotWrite(_ url: URL) -> PromptCastError {
        PromptCastError("Cannot write \(url.path). Check free disk space and that ~/PromptCast is writable.")
    }
}
