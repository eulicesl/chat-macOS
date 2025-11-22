//
//  SemanticSearch.swift
//  HuggingChat-iOS
//
//  Semantic search for memories using NaturalLanguage framework
//

import Foundation
import NaturalLanguage

actor SemanticSearch {
    static let shared = SemanticSearch()

    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    private init() {}

    // MARK: - Semantic Search

    func searchMemories(query: String, in memories: [Memory], limit: Int = 10) -> [ScoredMemory] {
        guard let queryEmbedding = embedding?.vector(for: query) else {
            // Fallback to keyword search
            return keywordSearch(query: query, in: memories, limit: limit)
        }

        var scoredMemories: [ScoredMemory] = []

        for memory in memories {
            if let memoryEmbedding = embedding?.vector(for: memory.content) {
                let similarity = cosineSimilarity(queryEmbedding, memoryEmbedding)

                // Boost by importance
                let score = similarity * (0.7 + memory.importance * 0.3)

                scoredMemories.append(ScoredMemory(
                    memory: memory,
                    score: score,
                    matchType: .semantic
                ))
            }
        }

        // Sort by score
        scoredMemories.sort { $0.score > $1.score }

        return Array(scoredMemories.prefix(limit))
    }

    func findSimilarMemories(to memory: Memory, in memories: [Memory], limit: Int = 5) -> [ScoredMemory] {
        return searchMemories(query: memory.content, in: memories, limit: limit)
    }

    // MARK: - Keyword Search (Fallback)

    private func keywordSearch(query: String, in memories: [Memory], limit: Int) -> [ScoredMemory] {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))

        var scoredMemories: [ScoredMemory] = []

        for memory in memories {
            let contentWords = Set(memory.content.lowercased().split(separator: " ").map(String.init))
            let tagWords = Set(memory.tags.map { $0.lowercased() })

            // Calculate overlap
            let contentOverlap = queryWords.intersection(contentWords).count
            let tagOverlap = queryWords.intersection(tagWords).count

            let score = (Double(contentOverlap) * 0.6 + Double(tagOverlap) * 0.4) / Double(queryWords.count)

            if score > 0 {
                scoredMemories.append(ScoredMemory(
                    memory: memory,
                    score: score * memory.importance,
                    matchType: .keyword
                ))
            }
        }

        scoredMemories.sort { $0.score > $1.score }

        return Array(scoredMemories.prefix(limit))
    }

    // MARK: - Helper Functions

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    // MARK: - Extract Keywords

    func extractKeywords(from text: String, limit: Int = 5) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        var keywords: [(String, NLTag)] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag = tag,
               tag == .noun || tag == .verb || tag == .adjective {
                let word = String(text[range])
                if word.count > 3 {
                    keywords.append((word, tag))
                }
            }
            return true
        }

        // Prefer nouns, then verbs, then adjectives
        keywords.sort { (a, b) in
            if a.1 != b.1 {
                if a.1 == .noun { return true }
                if b.1 == .noun { return false }
                if a.1 == .verb { return true }
                return false
            }
            return a.0.count > b.0.count
        }

        return Array(keywords.prefix(limit).map { $0.0 })
    }

    // MARK: - Cluster Memories

    func clusterMemories(_ memories: [Memory]) -> [MemoryCluster] {
        // Simple clustering based on tags and content similarity
        var clusters: [MemoryCluster] = []
        var processedMemories = Set<UUID>()

        for memory in memories {
            guard !processedMemories.contains(memory.id) else { continue }

            var clusterMemories = [memory]
            processedMemories.insert(memory.id)

            // Find similar memories
            for otherMemory in memories {
                guard !processedMemories.contains(otherMemory.id) else { continue }

                // Check tag overlap
                let tagOverlap = Set(memory.tags).intersection(Set(otherMemory.tags)).count
                if tagOverlap >= 2 {
                    clusterMemories.append(otherMemory)
                    processedMemories.insert(otherMemory.id)
                }
            }

            if clusterMemories.count >= 2 {
                let commonTags = clusterMemories
                    .flatMap { $0.tags }
                    .reduce(into: [:]) { counts, tag in counts[tag, default: 0] += 1 }
                    .filter { $0.value >= 2 }
                    .keys

                clusters.append(MemoryCluster(
                    memories: clusterMemories,
                    commonTags: Array(commonTags),
                    centroid: clusterMemories.first!.content
                ))
            }
        }

        return clusters
    }
}

// MARK: - Supporting Types

struct ScoredMemory: Identifiable {
    let id = UUID()
    let memory: Memory
    let score: Double
    let matchType: MatchType

    enum MatchType {
        case semantic
        case keyword
        case tag
    }
}

struct MemoryCluster: Identifiable {
    let id = UUID()
    let memories: [Memory]
    let commonTags: [String]
    let centroid: String

    var clusterName: String {
        if !commonTags.isEmpty {
            return commonTags.prefix(2).joined(separator: ", ")
        }
        return "Cluster \(id.uuidString.prefix(8))"
    }
}

