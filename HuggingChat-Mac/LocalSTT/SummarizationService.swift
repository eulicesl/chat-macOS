//
//  SummarizationService.swift
//  HuggingChat-Mac
//
//  On-device text summarization using Apple's Foundation Models
//

import Foundation
import FoundationModels
import Observation

/// Service for on-device text summarization
@Observable class SummarizationService {

    // MARK: - Public Properties
    var isSummarizing: Bool = false
    var currentSummary: String = ""
    var error: String?

    // MARK: - Private Properties
    private var session: LanguageModelSession?

    // MARK: - Initialization

    init() {
        checkAvailability()
    }

    // MARK: - Public Methods

    /// Check if Foundation Models are available on this system
    static func isAvailable() -> Bool {
        if #available(macOS 15.0, iOS 18.0, *) {
            return LanguageModel.isAvailable
        }
        return false
    }

    /// Summarize a transcript with a simple summary response
    func summarize(transcript: String, context: String? = nil) async throws -> String {
        guard Self.isAvailable() else {
            throw SummarizationError.notAvailable
        }

        guard #available(macOS 15.0, iOS 18.0, *) else {
            throw SummarizationError.notAvailable
        }

        guard !transcript.isEmpty else {
            throw SummarizationError.emptyInput
        }

        await MainActor.run {
            isSummarizing = true
            error = nil
        }

        defer {
            Task { @MainActor in
                isSummarizing = false
            }
        }

        // Create a new session
        var session = LanguageModelSession()

        // Build the prompt
        let prompt = buildSummarizationPrompt(transcript: transcript, context: context)

        do {
            // Get the summary
            let result = try await session.respond(to: prompt)
            let summary = result.content

            await MainActor.run {
                currentSummary = summary
            }

            return summary
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw SummarizationError.summarizationFailed(error.localizedDescription)
        }
    }

    /// Summarize a transcript with streaming updates
    func summarizeStream(transcript: String, context: String? = nil, onUpdate: @escaping (String) -> Void) async throws {
        guard Self.isAvailable() else {
            throw SummarizationError.notAvailable
        }

        guard #available(macOS 15.0, iOS 18.0, *) else {
            throw SummarizationError.notAvailable
        }

        guard !transcript.isEmpty else {
            throw SummarizationError.emptyInput
        }

        await MainActor.run {
            isSummarizing = true
            currentSummary = ""
            error = nil
        }

        defer {
            Task { @MainActor in
                isSummarizing = false
            }
        }

        // Create a new session
        var session = LanguageModelSession()

        // Build the prompt
        let prompt = buildSummarizationPrompt(transcript: transcript, context: context)

        do {
            // Stream the summary
            for try await partial in session.streamResponse(to: prompt) {
                let partialText = partial.content

                await MainActor.run {
                    currentSummary = partialText
                }

                onUpdate(partialText)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw SummarizationError.summarizationFailed(error.localizedDescription)
        }
    }

    /// Summarize a meeting transcript with key points extraction
    func summarizeMeeting(transcript: String) async throws -> MeetingSummary {
        guard Self.isAvailable() else {
            throw SummarizationError.notAvailable
        }

        guard #available(macOS 15.0, iOS 18.0, *) else {
            throw SummarizationError.notAvailable
        }

        await MainActor.run {
            isSummarizing = true
            error = nil
        }

        defer {
            Task { @MainActor in
                isSummarizing = false
            }
        }

        var session = LanguageModelSession()

        // Structured prompt for meeting summarization
        let prompt = """
        Analyze this meeting transcript and provide:
        1. A brief overview (2-3 sentences)
        2. Key points discussed (bullet points)
        3. Action items (if any)
        4. Decisions made (if any)

        Transcript:
        \(transcript)

        Format your response as:
        OVERVIEW:
        [overview text]

        KEY POINTS:
        - [point 1]
        - [point 2]

        ACTION ITEMS:
        - [action 1]
        - [action 2]

        DECISIONS:
        - [decision 1]
        - [decision 2]
        """

        do {
            let result = try await session.respond(to: prompt)
            let summary = parseMeetingSummary(result.content)

            await MainActor.run {
                currentSummary = result.content
            }

            return summary
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw SummarizationError.summarizationFailed(error.localizedDescription)
        }
    }

    /// Generate a concise title for the transcript
    func generateTitle(transcript: String) async throws -> String {
        guard Self.isAvailable() else {
            throw SummarizationError.notAvailable
        }

        guard #available(macOS 15.0, iOS 18.0, *) else {
            throw SummarizationError.notAvailable
        }

        var session = LanguageModelSession()

        let prompt = """
        Generate a short, descriptive title (3-6 words) for this transcript:

        \(transcript.prefix(500))

        Title:
        """

        do {
            let result = try await session.respond(to: prompt)
            return result.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw SummarizationError.summarizationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func buildSummarizationPrompt(transcript: String, context: String?) -> String {
        var prompt = "Summarize this transcript concisely"

        if let context = context, !context.isEmpty {
            prompt += " in the context of: \(context)"
        }

        prompt += ":\n\n\(transcript)"

        return prompt
    }

    private func parseMeetingSummary(_ text: String) -> MeetingSummary {
        var overview = ""
        var keyPoints: [String] = []
        var actionItems: [String] = []
        var decisions: [String] = []

        let sections = text.components(separatedBy: "\n\n")

        for section in sections {
            if section.contains("OVERVIEW:") {
                overview = section
                    .replacingOccurrences(of: "OVERVIEW:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if section.contains("KEY POINTS:") {
                let lines = section.components(separatedBy: "\n")
                keyPoints = lines
                    .filter { $0.hasPrefix("-") || $0.hasPrefix("•") }
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-• ")) }
            } else if section.contains("ACTION ITEMS:") {
                let lines = section.components(separatedBy: "\n")
                actionItems = lines
                    .filter { $0.hasPrefix("-") || $0.hasPrefix("•") }
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-• ")) }
            } else if section.contains("DECISIONS:") {
                let lines = section.components(separatedBy: "\n")
                decisions = lines
                    .filter { $0.hasPrefix("-") || $0.hasPrefix("•") }
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-• ")) }
            }
        }

        return MeetingSummary(
            overview: overview,
            keyPoints: keyPoints,
            actionItems: actionItems,
            decisions: decisions
        )
    }

    private func checkAvailability() {
        if !Self.isAvailable() {
            error = "Foundation Models require macOS 15.0 or later and may need to download models"
        }
    }
}

// MARK: - Data Models

struct MeetingSummary {
    let overview: String
    let keyPoints: [String]
    let actionItems: [String]
    let decisions: [String]

    var formattedString: String {
        var result = "Overview:\n\(overview)\n\n"

        if !keyPoints.isEmpty {
            result += "Key Points:\n"
            result += keyPoints.map { "• \($0)" }.joined(separator: "\n")
            result += "\n\n"
        }

        if !actionItems.isEmpty {
            result += "Action Items:\n"
            result += actionItems.map { "• \($0)" }.joined(separator: "\n")
            result += "\n\n"
        }

        if !decisions.isEmpty {
            result += "Decisions:\n"
            result += decisions.map { "• \($0)" }.joined(separator: "\n")
        }

        return result
    }
}

// MARK: - Error Types

enum SummarizationError: LocalizedError {
    case notAvailable
    case emptyInput
    case summarizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Foundation Models require macOS 15.0 or later"
        case .emptyInput:
            return "Cannot summarize empty text"
        case .summarizationFailed(let message):
            return "Summarization failed: \(message)"
        }
    }
}
