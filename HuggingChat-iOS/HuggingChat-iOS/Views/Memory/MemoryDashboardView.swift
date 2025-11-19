//
//  MemoryDashboardView.swift
//  HuggingChat-iOS
//
//  Dashboard for viewing and managing AI memory
//

import SwiftUI
import Charts

struct MemoryDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var memoryManager = MemoryManager.shared
    @State private var proactiveAssistant = ProactiveAssistant.shared
    @State private var behaviorAnalyzer = UserBehaviorAnalyzer.shared

    @State private var statistics: MemoryStatistics?
    @State private var selectedMemoryType: MemoryType = .conversation
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // Statistics Section
                Section("Memory Statistics") {
                    if let stats = statistics {
                        statisticsView(stats)
                    } else {
                        ProgressView()
                    }
                }

                // Proactive Suggestions
                Section("Proactive Suggestions") {
                    if proactiveAssistant.currentSuggestions.isEmpty {
                        Text("No suggestions at the moment")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(proactiveAssistant.currentSuggestions) { suggestion in
                            ProactiveSuggestionRow(suggestion: suggestion)
                        }
                    }
                }

                // Behavior Patterns
                Section("Learned Patterns") {
                    if behaviorAnalyzer.identifiedPatterns.isEmpty {
                        Text("Still learning your patterns...")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(behaviorAnalyzer.identifiedPatterns) { pattern in
                            PatternRow(pattern: pattern)
                        }
                    }
                }

                // Memory Browser
                Section("Browse Memories") {
                    Picker("Memory Type", selection: $selectedMemoryType) {
                        ForEach(MemoryType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    NavigationLink {
                        MemoryBrowserView(memoryType: selectedMemoryType)
                    } label: {
                        Label("View \(selectedMemoryType.rawValue.capitalized) Memories", systemImage: "doc.text.magnifyingglass")
                    }
                }

                // Privacy Controls
                Section("Privacy & Control") {
                    Toggle("Enable Proactive Assistant", isOn: Binding(
                        get: { proactiveAssistant.isEnabled },
                        set: { proactiveAssistant.toggleProactive($0) }
                    ))

                    Toggle("Monitor Clipboard", isOn: Binding(
                        get: { ContextProvider.shared.isMonitoring },
                        set: { _ in
                            if ContextProvider.shared.isMonitoring {
                                ContextProvider.shared.stopMonitoring()
                            } else {
                                ContextProvider.shared.startMonitoring()
                            }
                        }
                    ))

                    Button(role: .destructive) {
                        cleanupOldMemories()
                    } label: {
                        Label("Clean Up Old Memories", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        deleteAllMemories()
                    } label: {
                        Label("Delete All Memories", systemImage: "exclamationmark.triangle")
                    }
                }

                // Export/Import
                Section("Data Management") {
                    Button {
                        exportMemories()
                    } label: {
                        Label("Export Memories", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        // Import memories
                    } label: {
                        Label("Import Memories", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("AI Memory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshSuggestions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadStatistics()
            generateSuggestions()
        }
    }

    @ViewBuilder
    private func statisticsView(_ stats: MemoryStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(stats.totalMemories)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Memories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(String(format: "%.0f%%", stats.averageImportance * 100))
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Avg Importance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Memory type distribution chart
            if #available(iOS 16.0, *) {
                Chart(Array(stats.memoriesByType.keys), id: \.self) { type in
                    BarMark(
                        x: .value("Count", stats.memoriesByType[type] ?? 0),
                        y: .value("Type", type.rawValue.capitalized)
                    )
                    .foregroundStyle(by: .value("Type", type.rawValue))
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Actions

    private func loadStatistics() {
        statistics = memoryManager.getMemoryStatistics()
    }

    private func generateSuggestions() {
        _ = proactiveAssistant.generateSuggestions()
    }

    private func refreshSuggestions() {
        generateSuggestions()
        loadStatistics()
        HapticManager.shared.success()
    }

    private func cleanupOldMemories() {
        memoryManager.cleanupOldMemories(olderThan: 90, minImportance: 0.3)
        loadStatistics()
        HapticManager.shared.success()
    }

    private func deleteAllMemories() {
        memoryManager.deleteAllMemories()
        behaviorAnalyzer.interactionHistory.removeAll()
        loadStatistics()
        HapticManager.shared.warning()
    }

    private func exportMemories() {
        // Export to JSON
        let memories = memoryManager.recentMemories

        if let data = try? JSONEncoder().encode(memories),
           let jsonString = String(data: data, encoding: .utf8) {

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("memories_\(Date().timeIntervalSince1970).json")

            try? jsonString.write(to: tempURL, atomically: true, encoding: .utf8)

            // Share
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }

        HapticManager.shared.success()
    }
}

// MARK: - Proactive Suggestion Row

struct ProactiveSuggestionRow: View {
    let suggestion: ProactiveSuggestion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)

                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(suggestion.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }

            Spacer()

            Button {
                ProactiveAssistant.shared.executeSuggestion(suggestion)
                HapticManager.shared.success()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                ProactiveAssistant.shared.dismissSuggestion(suggestion)
                HapticManager.shared.light()
            } label: {
                Label("Dismiss", systemImage: "xmark")
            }
        }
    }
}

// MARK: - Pattern Row

struct PatternRow: View {
    let pattern: BehaviorPattern

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pattern.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(String(format: "%.0f%%", pattern.confidence * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(pattern.suggestion)
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: pattern.frequency)
                .tint(.blue)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MemoryDashboardView()
}
