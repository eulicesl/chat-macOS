//
//  ChatActivityAttributes.swift
//  HuggingChat-iOS
//
//  Live Activities for real-time message generation
//

import ActivityKit
import Foundation

// MARK: - Chat Activity Attributes

struct ChatActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentMessage: String
        var tokensGenerated: Int
        var isGenerating: Bool
        var progress: Double
    }

    var conversationTitle: String
    var modelName: String
}

// MARK: - Live Activity Manager

@Observable
class LiveActivityManager {
    private var currentActivity: Activity<ChatActivityAttributes>?

    func startGenerationActivity(conversationTitle: String, modelName: String) {
        let attributes = ChatActivityAttributes(
            conversationTitle: conversationTitle,
            modelName: modelName
        )

        let contentState = ChatActivityAttributes.ContentState(
            currentMessage: "",
            tokensGenerated: 0,
            isGenerating: true,
            progress: 0.0
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(message: String, tokens: Int, progress: Double) {
        guard let activity = currentActivity else { return }

        let contentState = ChatActivityAttributes.ContentState(
            currentMessage: message,
            tokensGenerated: tokens,
            isGenerating: true,
            progress: progress
        )

        Task {
            await activity.update(
                ActivityContent(
                    state: contentState,
                    staleDate: Date().addingTimeInterval(300)
                )
            )
        }
    }

    func endActivity(finalMessage: String, totalTokens: Int) {
        guard let activity = currentActivity else { return }

        let finalState = ChatActivityAttributes.ContentState(
            currentMessage: finalMessage,
            tokensGenerated: totalTokens,
            isGenerating: false,
            progress: 1.0
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 5)
            )
            currentActivity = nil
        }
    }

    func cancelActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}

// MARK: - Live Activity Widget

import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct ChatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChatActivityAttributes.self) { context in
            // Lock screen/banner UI
            LiveActivityView(context: context)
                .activityBackgroundTint(.cyan.opacity(0.2))
                .activitySystemActionForegroundColor(.cyan)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.cyan)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.tokensGenerated)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.conversationTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if context.state.isGenerating {
                            Text(context.state.currentMessage)
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isGenerating {
                        ProgressView(value: context.state.progress)
                            .tint(.cyan)
                    }
                }
            } compactLeading: {
                Image(systemName: "message.fill")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                if context.state.isGenerating {
                    ProgressView()
                        .tint(.cyan)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } minimal: {
                Image(systemName: context.state.isGenerating ? "message.fill" : "checkmark.circle.fill")
                    .foregroundStyle(context.state.isGenerating ? .cyan : .green)
            }
        }
    }
}

struct LiveActivityView: View {
    let context: ActivityViewContext<ChatActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "message.fill")
                .font(.title2)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.conversationTitle)
                    .font(.headline)
                    .lineLimit(1)

                if context.state.isGenerating {
                    Text(context.state.currentMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    ProgressView(value: context.state.progress)
                        .tint(.cyan)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Complete")
                            .font(.caption)
                    }
                }
            }

            Spacer()

            VStack {
                Text("\(context.state.tokensGenerated)")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
