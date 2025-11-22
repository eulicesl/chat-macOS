//
//  OnboardingView.swift
//  HuggingChat-iOS
//

import SwiftUI

struct OnboardingView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(CoordinatorModel.self) private var coordinator
    @Environment(\.window) private var window

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // Logo/Icon
                Image(systemName: "message.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.blue)

                VStack(spacing: 12) {
                    Text("Welcome to HuggingChat")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Chat with open-source AI models")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Task {
                            guard let window = await getKeyWindow() else { return }
                            try? await coordinator.signIn(presentationContext: window)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("Sign in with HuggingFace")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(coordinator.isAuthenticating)

                    if coordinator.isAuthenticating {
                        ProgressView()
                            .padding()
                    }

                    if let error = coordinator.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }

    @MainActor
    private func getKeyWindow() async -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

extension EnvironmentValues {
    @Entry var window: UIWindow? = nil
}

#Preview {
    OnboardingView()
        .environment(HuggingChatSession.shared)
        .environment(CoordinatorModel())
}
