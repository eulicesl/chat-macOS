//
//  KeyboardSettingsView.swift
//  HuggingChat
//
//  Settings and configuration for HuggingChat AI Keyboard
//

import SwiftUI

@MainActor
struct KeyboardSettingsView: View {
    @State private var viewModel = KeyboardSettingsViewModel()
    @State private var showingCommandEditor = false
    @State private var editingCommand: QuickCommand?

    var body: some View {
        List {
            // Setup Section
            Section {
                setupGuideView
            } header: {
                Text("Setup")
            } footer: {
                Text("Enable HuggingChat AI Keyboard in Settings > General > Keyboard > Keyboards > Add New Keyboard")
            }

            // Features Section
            Section("Features") {
                Toggle(isOn: $viewModel.allowNetworkAccess) {
                    Label("Allow Network Access", systemImage: "network")
                }

                Toggle(isOn: $viewModel.enableSmartSuggestions) {
                    Label("Smart Suggestions", systemImage: "sparkles")
                }

                Toggle(isOn: $viewModel.enableVoiceInput) {
                    Label("Voice Input", systemImage: "mic.fill")
                }

                Picker("Theme", selection: $viewModel.selectedTheme) {
                    ForEach(KeyboardTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }

            // Quick Commands Section
            Section {
                ForEach(viewModel.quickCommands) { command in
                    CommandRow(command: command, onToggle: { enabled in
                        viewModel.toggleCommand(command, enabled: enabled)
                    }, onEdit: {
                        editingCommand = command
                        showingCommandEditor = true
                    })
                }

                Button(action: {
                    editingCommand = nil
                    showingCommandEditor = true
                }) {
                    Label("Add Custom Command", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Quick Commands")
            } footer: {
                Text("Create custom commands for quick AI assistance")
            }

            // Model Selection
            Section("Default AI Model") {
                Picker("Model", selection: $viewModel.selectedModelId) {
                    ForEach(viewModel.availableModels, id: \.id) { model in
                        VStack(alignment: .leading) {
                            Text(model.name)
                            Text(model.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model.id)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            // Privacy Section
            Section {
                Label("All data stays on device", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)

                Label("No data sent to third parties", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.secondary)

                Label("Network access only for AI requests", systemImage: "network.badge.shield.half.filled")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
            } footer: {
                Text("The keyboard requires Full Access to communicate with the main app via App Groups and make AI requests. Your data is never shared with third parties.")
            }

            // Usage Tips
            Section("Usage Tips") {
                TipRow(
                    icon: "command",
                    title: "Quick Commands",
                    description: "Type /ai, /translate, /improve and more for instant AI help"
                )

                TipRow(
                    icon: "mic.fill",
                    title: "Voice Input",
                    description: "Switch to voice mode for hands-free transcription"
                )

                TipRow(
                    icon: "sparkles",
                    title: "Smart Suggestions",
                    description: "Get context-aware completions based on your typing"
                )
            }

            // Data Management
            Section("Data") {
                Button(action: viewModel.clearRecentCompletions) {
                    Label("Clear Recent Completions", systemImage: "trash")
                        .foregroundStyle(.red)
                }

                Button(action: viewModel.resetToDefaults) {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("AI Keyboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCommandEditor) {
            commandEditorSheet
        }
        .onChange(of: viewModel.allowNetworkAccess) { @MainActor _ in
            persistSettings()
        }
        .onChange(of: viewModel.enableSmartSuggestions) { @MainActor _ in
            persistSettings()
        }
        .onChange(of: viewModel.enableVoiceInput) { @MainActor _ in
            persistSettings()
        }
        .onChange(of: viewModel.selectedTheme) { @MainActor _ in
            persistSettings()
        }
        .onChange(of: viewModel.selectedModelId) { @MainActor _ in
            persistSettings()
        }
    }

    @MainActor
    private func persistSettings() {
        viewModel.saveSettings()
    }

    private var setupGuideView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("Enable AI Keyboard")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                SetupStep(number: 1, text: "Open Settings app")
                SetupStep(number: 2, text: "Go to General > Keyboard > Keyboards")
                SetupStep(number: 3, text: "Tap 'Add New Keyboard'")
                SetupStep(number: 4, text: "Select 'HuggingChat AI'")
                SetupStep(number: 5, text: "Enable 'Allow Full Access'")
            }
            .padding(.leading, 8)

            Button(action: openKeyboardSettings) {
                Label("Open Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 8)
    }

    private var commandEditorSheet: some View {
        CommandEditorView(
            command: editingCommand,
            onSave: handleSaveCommand(_:)
        )
    }

    private func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    private func handleSaveCommand(_ command: QuickCommand) {
        viewModel.saveCommand(command)
        showingCommandEditor = false
    }
}

// MARK: - Supporting Views

struct CommandRow: View {
    let command: QuickCommand
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: command.icon)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.trigger)
                    .font(.headline)

                Text(command.prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { command.isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Command Editor

struct CommandEditorView: View {
    let command: QuickCommand?
    let onSave: (QuickCommand) -> Void

    @State private var trigger: String = ""
    @State private var prompt: String = ""
    @State private var selectedIcon: String = "sparkles"
    @Environment(\.dismiss) private var dismiss

    private let availableIcons = [
        "sparkles", "wand.and.stars", "globe", "checkmark.circle",
        "lightbulb", "briefcase", "person.2", "list.bullet.clipboard",
        "text.bubble", "doc.text", "character.cursor.ibeam"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Command Trigger") {
                    TextField("/command", text: $trigger)
                        .autocapitalization(.none)
                }

                Section("AI Prompt") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? Color.white : Color.primary)
                                    .frame(width: 60, height: 60)
                                    .background(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                Section {
                    Text("Use {input} in your prompt to insert user input")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Tips")
                }
            }
            .navigationTitle(command == nil ? "New Command" : "Edit Command")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCommand()
                    }
                    .disabled(trigger.isEmpty || prompt.isEmpty)
                }
            }
            .onAppear {
                if let command = command {
                    trigger = command.trigger
                    prompt = command.prompt
                    selectedIcon = command.icon
                } else {
                    trigger = "/"
                }
            }
        }
    }

    private func saveCommand() {
        let newCommand = QuickCommand(
            id: command?.id ?? UUID(),
            trigger: trigger,
            prompt: prompt,
            icon: selectedIcon,
            isEnabled: command?.isEnabled ?? true
        )
        onSave(newCommand)
    }
}

// MARK: - View Model

@MainActor
@Observable
class KeyboardSettingsViewModel {
    var allowNetworkAccess: Bool = true
    var enableSmartSuggestions: Bool = true
    var enableVoiceInput: Bool = true
    var selectedTheme: KeyboardTheme = .auto
    var selectedModelId: String = ""
    var quickCommands: [QuickCommand] = []
    var availableModels: [LLMModel] = []

    private let sharedData = SharedDataManager.shared
    private let session = HuggingChatSession.shared

    init() {
        loadSettings()
        loadModels()
    }

    func loadSettings() {
        allowNetworkAccess = sharedData.allowNetworkAccess
        enableSmartSuggestions = sharedData.enableSmartSuggestions
        enableVoiceInput = sharedData.enableVoiceInput
        selectedTheme = sharedData.keyboardTheme
        selectedModelId = sharedData.selectedModelId
        quickCommands = sharedData.getQuickCommands()
    }

    func saveSettings() {
        sharedData.allowNetworkAccess = allowNetworkAccess
        sharedData.enableSmartSuggestions = enableSmartSuggestions
        sharedData.enableVoiceInput = enableVoiceInput
        sharedData.keyboardTheme = selectedTheme
        sharedData.selectedModelId = selectedModelId
        sharedData.synchronize()

        // Session token saving disabled: session.sessionToken not available in current API
    }

    func loadModels() {
        // NetworkService.fetchModels not available; use empty list fallback
        availableModels = []
        // Keep existing selectedModelId if set; otherwise leave empty
    }

    func toggleCommand(_ command: QuickCommand, enabled: Bool) {
        if let index = quickCommands.firstIndex(where: { $0.id == command.id }) {
            quickCommands[index] = QuickCommand(
                id: command.id,
                trigger: command.trigger,
                prompt: command.prompt,
                icon: command.icon,
                isEnabled: enabled
            )
            sharedData.saveQuickCommands(quickCommands)
        }
    }

    func saveCommand(_ command: QuickCommand) {
        if let index = quickCommands.firstIndex(where: { $0.id == command.id }) {
            quickCommands[index] = command
        } else {
            quickCommands.append(command)
        }
        sharedData.saveQuickCommands(quickCommands)
    }

    func clearRecentCompletions() {
        sharedData.saveRecentCompletions([])
    }

    func resetToDefaults() {
        quickCommands = QuickCommand.defaultCommands
        sharedData.saveQuickCommands(quickCommands)
        allowNetworkAccess = true
        enableSmartSuggestions = true
        enableVoiceInput = true
        selectedTheme = .auto
        saveSettings()
    }
}

#Preview {
    NavigationStack {
        KeyboardSettingsView()
    }
}
