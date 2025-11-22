//
//  CodeCompletionView.swift
//  HuggingChatKeyboard
//
//  Code completion mode for developers
//  Provides intelligent code suggestions and completions
//

import SwiftUI

struct CodeCompletionView: View {
    @Bindable var viewModel: KeyboardViewModel
    @State private var codeInput: String = ""
    @State private var selectedLanguage: CodeLanguage = .swift
    @State private var completionType: CompletionType = .autocomplete

    var body: some View {
        VStack(spacing: 8) {
            // Language and type selector
            HStack {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(CodeLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)

                Spacer()

                Picker("Type", selection: $completionType) {
                    ForEach(CompletionType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            .padding(.horizontal)

            // Code input area
            HStack(alignment: .top) {
                TextEditor(text: $codeInput)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)

                VStack(spacing: 8) {
                    Button(action: { Task { await complete() } }) {
                        Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .disabled(codeInput.isEmpty || viewModel.isLoading)

                    Button(action: { codeInput = "" }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            // Quick actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickCodeButton(icon: "function", title: "Function") {
                        insertSnippet("function")
                    }

                    QuickCodeButton(icon: "curlybraces", title: "Class") {
                        insertSnippet("class")
                    }

                    QuickCodeButton(icon: "arrow.triangle.branch", title: "If/Else") {
                        insertSnippet("ifelse")
                    }

                    QuickCodeButton(icon: "arrow.triangle.2.circlepath", title: "Loop") {
                        insertSnippet("loop")
                    }

                    QuickCodeButton(icon: "exclamationmark.triangle", title: "Try/Catch") {
                        insertSnippet("trycatch")
                    }

                    QuickCodeButton(icon: "questionmark.circle", title: "Explain") {
                        Task { await explainCode() }
                    }
                }
                .padding(.horizontal)
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 4)
    }

    private func complete() async {
        let prompt: String

        switch completionType {
        case .autocomplete:
            prompt = "Complete this \(selectedLanguage.displayName) code:\n\n\(codeInput)"
        case .fix:
            prompt = "Fix any errors in this \(selectedLanguage.displayName) code:\n\n\(codeInput)"
        case .optimize:
            prompt = "Optimize this \(selectedLanguage.displayName) code:\n\n\(codeInput)"
        case .document:
            prompt = "Add documentation comments to this \(selectedLanguage.displayName) code:\n\n\(codeInput)"
        }

        await viewModel.executeAIRequest(prompt)
        codeInput = ""
    }

    private func explainCode() async {
        await viewModel.executeAIRequest("Explain what this code does:\n\n\(codeInput)")
    }

    private func insertSnippet(_ type: String) {
        let snippet = CodeSnippets.get(type, language: selectedLanguage)
        codeInput += snippet
    }
}

struct QuickCodeButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 70, height: 60)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

// MARK: - Code Language

enum CodeLanguage: String, CaseIterable, Identifiable, Codable {
    case swift, python, javascript, typescript, java, kotlin, go, rust, cpp, csharp, ruby, php

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .go: return "Go"
        case .rust: return "Rust"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        }
    }
}

enum CompletionType: String, CaseIterable, Identifiable {
    case autocomplete, fix, optimize, document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autocomplete: return "Complete"
        case .fix: return "Fix"
        case .optimize: return "Optimize"
        case .document: return "Document"
        }
    }

    var icon: String {
        switch self {
        case .autocomplete: return "arrow.right"
        case .fix: return "wrench"
        case .optimize: return "speedometer"
        case .document: return "doc.text"
        }
    }
}

// MARK: - Code Snippets

struct CodeSnippets {
    static func get(_ type: String, language: CodeLanguage) -> String {
        switch (type, language) {
        case ("function", .swift):
            return "\nfunc functionName() {\n    \n}\n"
        case ("class", .swift):
            return "\nclass ClassName {\n    \n}\n"
        case ("ifelse", .swift):
            return "\nif condition {\n    \n} else {\n    \n}\n"
        case ("loop", .swift):
            return "\nfor item in items {\n    \n}\n"
        case ("trycatch", .swift):
            return "\ndo {\n    try \n} catch {\n    \n}\n"

        case ("function", .python):
            return "\ndef function_name():\n    pass\n"
        case ("class", .python):
            return "\nclass ClassName:\n    pass\n"

        default:
            return "\n// Snippet for \(type) in \(language.displayName)\n"
        }
    }
}
