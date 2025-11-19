import Foundation
import OSLog

/// Service responsible for turning transcripts into structured meeting summaries using OpenAI Chat Completions.
actor MeetingSummaryService {
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: MeetingSummaryService.self))

    enum SummaryError: LocalizedError {
        case invalidAPIKey
        case emptyTranscript
        case encodingError(Error)
        case networkError(Error)
        case apiError(String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Invalid or missing OpenAI API key. Please set your API key in OpenAIConfig.swift"
            case .emptyTranscript:
                return "Transcript is empty. Cannot create a meeting summary without content."
            case .encodingError(let error):
                return "Failed to encode summary request: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "OpenAI API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode summary response: \(error.localizedDescription)"
            }
        }
    }

    struct Metadata: Sendable {
        let appName: String
        let startedAt: Date
        let endedAt: Date

        var duration: TimeInterval {
            max(0, endedAt.timeIntervalSince(startedAt))
        }
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatCompletionRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
    }

    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let role: String
                let content: String
            }

            let index: Int
            let message: Message
        }

        let choices: [Choice]
    }

    private struct ErrorResponse: Decodable {
        struct ErrorDetail: Decodable {
            let message: String
            let type: String?
            let code: String?
        }

        let error: ErrorDetail
    }

    /// Generates a markdown meeting summary for the provided transcript.
    func summarize(transcript: String, metadata: Metadata) async throws -> String {
        guard OpenAIConfig.apiKey != "api-key", !OpenAIConfig.apiKey.isEmpty else {
            throw SummaryError.invalidAPIKey
        }

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummaryError.emptyTranscript
        }

        let urlString = "\(OpenAIConfig.baseURL)/chat/completions"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid chat completions URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are an expert meeting note-taker. Summarize the meeting transcript in clear Markdown using the following sections:
        - Agenda / Topics
        - Decisions
        - Action Items (with owners if mentioned)
        - Risks / Follow-ups (if applicable)
        Keep the summary concise but comprehensive, and prefer bullet lists when appropriate.
        """

        let metadataBlock = renderMetadata(metadata)
        let userPrompt = """
        Meeting context:
        \(metadataBlock)

        Transcript:
        \(transcript)
        """

        let body = ChatCompletionRequest(
            model: OpenAIConfig.summaryModel,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.2
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            logger.error("Failed to encode summary request: \(error.localizedDescription, privacy: .public)")
            throw SummaryError.encodingError(error)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SummaryError.networkError(NSError(domain: "Invalid response", code: -1))
            }

            logger.debug("Summary response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                    guard let content = decoded.choices.first?.message.content else {
                        throw SummaryError.apiError("No summary returned from API")
                    }
                    logger.info("Summary completed (\(content.count) characters)")
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    logger.error("Failed to decode summary response: \(error.localizedDescription, privacy: .public)")
                    throw SummaryError.decodingError(error)
                }

            default:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    logger.error("API error: \(errorResponse.error.message, privacy: .public)")
                    throw SummaryError.apiError(errorResponse.error.message)
                } else if let errorString = String(data: data, encoding: .utf8) {
                    logger.error("API error (raw): \(errorString, privacy: .public)")
                    throw SummaryError.apiError(errorString)
                } else {
                    throw SummaryError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
        } catch let error as SummaryError {
            throw error
        } catch {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            throw SummaryError.networkError(error)
        }
    }

    private func renderMetadata(_ metadata: Metadata) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current
        dateFormatter.timeZone = .current

        let durationFormatter = DateComponentsFormatter()
        durationFormatter.allowedUnits = [.hour, .minute, .second]
        durationFormatter.unitsStyle = .abbreviated

        let durationString = durationFormatter.string(from: metadata.duration) ?? "-"
        let start = dateFormatter.string(from: metadata.startedAt)
        let end = dateFormatter.string(from: metadata.endedAt)

        return """
        - Application: \(metadata.appName)
        - Started: \(start)
        - Ended: \(end)
        - Duration: \(durationString)
        """
    }
}
