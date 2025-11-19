//
//  MemoryBrowserView.swift
//  HuggingChat-iOS
//
//  Browse and search memories with semantic search
//

import SwiftUI

struct MemoryBrowserView: View {
    let memoryType: MemoryType

    @State private var memories: [Memory] = []
    @State private var searchText = ""
    @State private var searchResults: [ScoredMemory] = []
    @State private var isSearching = false

    var body: some View {
        List {
            if !searchText.isEmpty {
                // Search results
                Section("Search Results") {
                    if searchResults.isEmpty {
                        Text("No memories found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(searchResults) { scoredMemory in
                            MemoryRow(
                                memory: scoredMemory.memory,
                                score: scoredMemory.score,
                                matchType: scoredMemory.matchType
                            )
                        }
                    }
                }
            } else {
                // All memories of type
                if memories.isEmpty {
                    Text("No \(memoryType.rawValue) memories yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memories) { memory in
                        MemoryRow(memory: memory)
                    }
                }
            }
        }
        .navigationTitle("\(memoryType.rawValue.capitalized) Memories")
        .searchable(text: $searchText, prompt: "Search memories...")
        .onChange(of: searchText) { _, newValue in
            performSearch(newValue)
        }
        .onAppear {
            loadMemories()
        }
    }

    private func loadMemories() {
        memories = MemoryManager.shared.getMemoriesByType(memoryType, limit: 100)
    }

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        // Perform semantic search
        searchResults = SemanticSearch.shared.searchMemories(
            query: query,
            in: memories,
            limit: 20
        )

        isSearching = false
    }
}

struct MemoryRow: View {
    let memory: Memory
    var score: Double?
    var matchType: ScoredMemory.MatchType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(memory.content)
                    .font(.subheadline)
                    .lineLimit(3)

                Spacer()

                if let score = score {
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let context = memory.context {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                ForEach(memory.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                Text(memory.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let matchType = matchType {
                    Image(systemName: matchType == .semantic ? "brain" : "text.magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ImportanceIndicator(importance: memory.importance)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                markAsUseful()
            } label: {
                Label("Mark as Useful", systemImage: "hand.thumbsup")
            }

            Button {
                markAsNotUseful()
            } label: {
                Label("Mark as Not Useful", systemImage: "hand.thumbsdown")
            }

            Button(role: .destructive) {
                // Delete memory
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func markAsUseful() {
        MemoryManager.shared.markMemoryAsUseful(id: memory.id)
        HapticManager.shared.success()
    }

    private func markAsNotUseful() {
        MemoryManager.shared.markMemoryAsNotUseful(id: memory.id)
        HapticManager.shared.light()
    }
}

struct ImportanceIndicator: View {
    let importance: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < Int(importance * 5) ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }

            Text(String(format: "%.0f%%", importance * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        MemoryBrowserView(memoryType: .conversation)
    }
}
