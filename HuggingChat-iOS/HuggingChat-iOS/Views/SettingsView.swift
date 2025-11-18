//
//  SettingsView.swift
//  HuggingChat-iOS
//

import SwiftUI

struct SettingsView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(ThemingEngine.self) private var themingEngine
    @Environment(AudioModelManager.self) private var audioManager

    @AppStorage("useWebSearch") private var useWebSearch = false
    @AppStorage("baseURL") private var baseURL = "https://huggingface.co"

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    if let user = session.currentUser {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Button(role: .destructive) {
                            session.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        HStack {
                            Text("Theme")
                            Spacer()
                            Text(themingEngine.currentTheme.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Chat Settings
                Section("Chat Settings") {
                    Toggle("Enable Web Search by Default", isOn: $useWebSearch)
                }

                // Voice Settings
                Section("Voice") {
                    NavigationLink {
                        VoiceSettingsView()
                    } label: {
                        HStack {
                            Text("Speech Recognition")
                            Spacer()
                            Text(audioManager.modelState == .loaded ? "Ready" : "Not Loaded")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Advanced Section
                Section("Advanced") {
                    TextField("Base URL", text: $baseURL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                // About Section
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")

                    Link(destination: URL(string: "https://huggingface.co/chat")!) {
                        Label("HuggingChat Website", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct ThemeSelectionView: View {
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        List {
            ForEach(Theme.allThemes) { theme in
                Button {
                    themingEngine.setTheme(theme)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(theme.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(theme.primaryColor)
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .fill(theme.backgroundColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.secondary, lineWidth: 1)
                                    )
                            }
                        }

                        Spacer()

                        if themingEngine.currentTheme.id == theme.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Theme")
    }
}

struct VoiceSettingsView: View {
    @Environment(AudioModelManager.self) private var audioManager

    var body: some View {
        List {
            Section {
                switch audioManager.modelState {
                case .unloaded:
                    Button {
                        Task {
                            await audioManager.loadModel()
                        }
                    } label: {
                        Label("Load Whisper Model", systemImage: "arrow.down.circle")
                    }

                case .loading:
                    HStack {
                        ProgressView()
                        Text("Loading model...")
                    }

                case .loaded:
                    Label("Model Ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                case .error(let error):
                    VStack(alignment: .leading) {
                        Label("Error", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Whisper Model")
            } footer: {
                Text("WhisperKit provides on-device speech recognition for voice input.")
            }
        }
        .navigationTitle("Voice Settings")
    }
}

#Preview {
    SettingsView()
        .environment(HuggingChatSession.shared)
        .environment(ThemingEngine())
        .environment(AudioModelManager())
}
