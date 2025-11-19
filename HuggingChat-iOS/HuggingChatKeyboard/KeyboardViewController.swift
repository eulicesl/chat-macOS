//
//  KeyboardViewController.swift
//  HuggingChatKeyboard
//
//  Main keyboard view controller for HuggingChat AI Keyboard
//

import UIKit
import SwiftUI

/// Main view controller for HuggingChat custom keyboard
class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardView>?
    private let keyboardViewModel = KeyboardViewModel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the SwiftUI keyboard view
        setupKeyboardView()

        // Set keyboard height
        setupKeyboardHeight()

        // Configure text document proxy delegate
        setupTextDocumentProxy()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardViewModel.loadSettings()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        keyboardViewModel.updateContext(from: textDocumentProxy)
    }

    // MARK: - Setup

    private func setupKeyboardView() {
        // Create SwiftUI view with view model
        let keyboardView = KeyboardView(
            viewModel: keyboardViewModel,
            textDocumentProxy: textDocumentProxy,
            requestNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            dismissKeyboard: { [weak self] in
                self?.dismissKeyboard()
            }
        )

        // Host SwiftUI view in UIKit
        let hosting = UIHostingController(rootView: keyboardView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.hostingController = hosting
    }

    private func setupKeyboardHeight() {
        // Set preferred height for keyboard
        let height: CGFloat = keyboardViewModel.keyboardMode == .ai ? 350 : 250

        if let constraint = view.constraints.first(where: { $0.firstAttribute == .height }) {
            constraint.constant = height
        } else {
            view.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }

    private func setupTextDocumentProxy() {
        // Monitor text changes for context awareness
        keyboardViewModel.textDocumentProxy = textDocumentProxy
    }

    // MARK: - Actions

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate { _ in
            self.setupKeyboardHeight()
        }
    }
}

// MARK: - KeyboardView Model

@Observable
class KeyboardViewModel {
    var textDocumentProxy: UITextDocumentProxy?
    var keyboardMode: KeyboardMode = .standard
    var currentText: String = ""
    var isLoading: Bool = false
    var suggestions: [String] = []
    var recentCompletions: [AICompletion] = []
    var quickCommands: [QuickCommand] = []
    var errorMessage: String?

    // Settings
    var allowNetworkAccess: Bool = true
    var enableSmartSuggestions: Bool = true
    var enableVoiceInput: Bool = true
    var selectedTheme: KeyboardTheme = .auto

    // Services
    private let sharedData = SharedDataManager.shared
    private let commandParser = CommandParser()
    private let networkService = KeyboardNetworkService.shared
    private let voiceService = VoiceTranscriptionService.shared

    init() {
        loadSettings()
        loadQuickCommands()
        setupVoiceService()
    }

    func loadSettings() {
        allowNetworkAccess = sharedData.allowNetworkAccess
        enableSmartSuggestions = sharedData.enableSmartSuggestions
        enableVoiceInput = sharedData.enableVoiceInput
        selectedTheme = sharedData.keyboardTheme
        recentCompletions = sharedData.getRecentCompletions()
    }

    func loadQuickCommands() {
        quickCommands = sharedData.getQuickCommands()
    }

    func setupVoiceService() {
        voiceService.onTranscriptionUpdate = { [weak self] transcription in
            Task { @MainActor in
                self?.currentText = transcription
            }
        }

        voiceService.onTranscriptionComplete = { [weak self] transcription in
            Task { @MainActor in
                self?.insertText(transcription)
                self?.switchMode(.standard)
            }
        }

        voiceService.onError = { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func updateContext(from proxy: UITextDocumentProxy) {
        // Get context before and after cursor
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        currentText = before + after

        // Check for quick commands
        if before.contains("/") {
            detectQuickCommand(in: before)
        }

        // Generate smart suggestions if enabled
        if enableSmartSuggestions {
            generateSuggestions(for: before, after: after)
        }
    }

    func detectQuickCommand(in text: String) {
        let words = text.components(separatedBy: .whitespaces)
        guard let lastWord = words.last, lastWord.hasPrefix("/") else {
            suggestions = []
            return
        }

        // Filter commands that match
        let matching = quickCommands.filter {
            $0.trigger.lowercased().hasPrefix(lastWord.lowercased()) && $0.isEnabled
        }
        suggestions = matching.map { $0.trigger }
    }

    func generateSuggestions(for before: String, after: String) {
        let context = commandParser.extractContext(before: before, after: after)
        let generatedSuggestions = commandParser.generateSuggestions(
            for: context,
            commands: quickCommands
        )

        // Update suggestions (only show top 5)
        suggestions = generatedSuggestions.prefix(5).map { $0.text }
    }

    func executeCommand(_ command: QuickCommand, with input: String) async {
        guard allowNetworkAccess else {
            await MainActor.run {
                errorMessage = "Network access is disabled"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            // Build prompt from command
            let prompt = commandParser.buildPrompt(for: command, with: input)

            // Get AI completion
            let completion = try await networkService.getCompletion(prompt: prompt)

            await MainActor.run {
                // Insert completion into text field
                insertText(completion)

                // Save to recent completions
                saveCompletion(prompt: input, completion: completion)

                // Switch back to standard mode
                switchMode(.standard)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func executeAIRequest(_ prompt: String) async {
        guard allowNetworkAccess else {
            await MainActor.run {
                errorMessage = "Network access is disabled"
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            // Get context and enhance prompt
            let before = textDocumentProxy?.documentContextBeforeInput ?? ""
            let after = textDocumentProxy?.documentContextAfterInput ?? ""
            let context = commandParser.extractContext(before: before, after: after)
            let enhancedPrompt = commandParser.enhancePrompt(prompt, with: context)

            // Get AI completion
            let completion = try await networkService.getCompletion(prompt: enhancedPrompt)

            await MainActor.run {
                // Insert completion
                insertText(completion)

                // Save to recent completions
                saveCompletion(prompt: prompt, completion: completion)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startVoiceRecording() async {
        // Request permissions if needed
        let hasPermissions = await voiceService.requestPermissions()

        guard hasPermissions else {
            await MainActor.run {
                errorMessage = "Microphone permission required"
            }
            return
        }

        do {
            try voiceService.startRecording()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopVoiceRecording() {
        voiceService.stopRecording()
    }

    func switchMode(_ mode: KeyboardMode) {
        keyboardMode = mode
        errorMessage = nil
    }

    // MARK: - Text Manipulation

    func insertText(_ text: String) {
        textDocumentProxy?.insertText(text)
    }

    func deleteBackward() {
        textDocumentProxy?.deleteBackward()
    }

    // MARK: - Persistence

    private func saveCompletion(prompt: String, completion: String) {
        let aiCompletion = AICompletion(
            prompt: prompt,
            completion: completion,
            modelId: sharedData.selectedModelId
        )

        var completions = recentCompletions
        completions.insert(aiCompletion, at: 0)
        completions = Array(completions.prefix(10)) // Keep only 10 most recent

        sharedData.saveRecentCompletions(completions)
        recentCompletions = completions
    }
}

enum KeyboardMode {
    case standard
    case ai
    case voice
    case commands
}
