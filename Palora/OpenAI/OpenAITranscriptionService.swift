import Foundation
import OSLog

/// Service for transcribing audio files using OpenAI's Whisper API
actor OpenAITranscriptionService {
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: OpenAITranscriptionService.self))
    
    enum TranscriptionError: LocalizedError {
        case invalidAPIKey
        case invalidAudioFile
        case networkError(Error)
        case apiError(String)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Invalid or missing OpenAI API key. Please set your API key in OpenAIConfig.swift"
            case .invalidAudioFile:
                return "The audio file could not be read or is invalid"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "OpenAI API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode API response: \(error.localizedDescription)"
            }
        }
    }
    
    struct TranscriptionResponse: Codable {
        let text: String
    }
    
    struct ErrorResponse: Codable {
        let error: ErrorDetail
        
        struct ErrorDetail: Codable {
            let message: String
            let type: String?
            let code: String?
        }
    }
    
    /// Transcribe an audio file using OpenAI Whisper
    /// - Parameter audioFileURL: URL to the audio file
    /// - Returns: The transcribed text
    func transcribe(audioFile audioFileURL: URL) async throws -> String {
        logger.info("Starting transcription for \(audioFileURL.lastPathComponent)")
        print("API key:", OpenAIConfig.apiKey)
        
        // Validate API key
        guard OpenAIConfig.apiKey != "api-key" 
        && !OpenAIConfig.apiKey.isEmpty else {
            logger.error("Invalid API key")
            throw TranscriptionError.invalidAPIKey
        }
        
        // Validate audio file exists
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            logger.error("Audio file not found at \(audioFileURL.path)")
            throw TranscriptionError.invalidAudioFile
        }
        
        // Create multipart form data request
        let boundary = UUID().uuidString
        print("Base URL:", OpenAIConfig.baseURL)
        let full = "\(OpenAIConfig.baseURL)/audio/transcriptions"
        print("Full URL:", full)
        guard let url = URL(string: full) else {
            fatalError("Invalid URL: \(full)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart form data
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(OpenAIConfig.transcriptionModel)\r\n")
        
        // Add language parameter (optional, set to English)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        body.append("en\r\n")
        
        // Add audio file
        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            logger.error("Failed to read audio file data")
            throw TranscriptionError.invalidAudioFile
        }
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioFileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")
        
        // Close boundary
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        // Send request
        logger.debug("Sending transcription request (file size: \(audioData.count) bytes)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            logger.debug("Received response with status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Success - decode transcription
                let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                logger.info("Transcription completed successfully (\(transcriptionResponse.text.count) characters)")
                return transcriptionResponse.text
            } else {
                // Error - try to decode error message
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    logger.error("API error: \(errorResponse.error.message)")
                    throw TranscriptionError.apiError(errorResponse.error.message)
                } else if let errorString = String(data: data, encoding: .utf8) {
                    logger.error("API error (raw): \(errorString)")
                    throw TranscriptionError.apiError(errorString)
                } else {
                    throw TranscriptionError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            if let urlError = error as? URLError {
                print("URLError code:", urlError.code.rawValue, urlError.code)
            }
            logger.error("Network error: \(error.localizedDescription)")
            throw TranscriptionError.networkError(error)
        }
    }
}

// Helper extension for Data
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

