//
//  HFError.swift
//  HuggingChat-iOS
//

import Foundation

enum HFError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case unauthorized
    case notFound
    case rateLimited
    case serverError(Int)
    case invalidURL
    case noData
    case customError(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .serverError(let code):
            return "Server error (\(code))"
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .customError(let message):
            return message
        }
    }
}
