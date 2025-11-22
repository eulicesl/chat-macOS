// //  LLMModel.swift
//  HuggingChat-iOS
//

import Foundation

struct LLMModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let description: String?
    let websiteUrl: String?
    let modelUrl: String?
    let preprompt: String?
    let promptExamples: [PromptExample]?
    let parameters: ModelParameters?
    let multimodal: Bool?
    let unlisted: Bool?
    let tools: Bool?

    struct PromptExample: Codable, Hashable {
        let title: String
        let prompt: String
    }

    struct ModelParameters: Codable, Hashable {
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let maxNewTokens: Int?
        let repetitionPenalty: Double?
        let stop: [String]?

        enum CodingKeys: String, CodingKey {
            case temperature
            case topP = "top_p"
            case topK = "top_k"
            case maxNewTokens = "max_new_tokens"
            case repetitionPenalty = "repetition_penalty"
            case stop
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        lhs.id == rhs.id
    }
}

extension LLMModel {
    static let preview = LLMModel(
        id: "meta-llama/Meta-Llama-3.1-70B-Instruct",
        name: "meta-llama/Meta-Llama-3.1-70B-Instruct",
        displayName: "Llama 3.1 70B",
        description: "Meta's Llama 3.1 70B Instruct model",
        websiteUrl: "https://huggingface.co/meta-llama/Meta-Llama-3.1-70B-Instruct",
        modelUrl: nil,
        preprompt: "",
        promptExamples: nil,
        parameters: nil,
        multimodal: false,
        unlisted: false,
        tools: false
    )
}
