//
//  HuggingChatWidget.swift
//  HuggingChatWidget
//
//  Widgets for Home Screen and Lock Screen
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Bundle

@main
struct HuggingChatWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentConversationsWidget()
        QuickChatWidget()
        ConversationCountWidget()
    }
}

// MARK: - Recent Conversations Widget

struct RecentConversationsWidget: Widget {
    let kind: String = "RecentConversationsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: RecentConversationsProvider()
        ) { entry in
            RecentConversationsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Chats")
        .description("View your recent conversations")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RecentConversationsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RecentConversationsEntry {
        RecentConversationsEntry(date: Date(), conversations: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> RecentConversationsEntry {
        RecentConversationsEntry(date: Date(), conversations: [])
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<RecentConversationsEntry> {
        let session = HuggingChatSession.shared
        let conversations = Array(session.conversations.prefix(5))

        let entry = RecentConversationsEntry(date: Date(), conversations: conversations)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))

        return timeline
    }
}

struct RecentConversationsEntry: TimelineEntry {
    let date: Date
    let conversations: [Conversation]
}

struct RecentConversationsWidgetView: View {
    var entry: RecentConversationsEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recent Chats", systemImage: "message.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            if entry.conversations.isEmpty {
                Text("No conversations yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.conversations.prefix(widgetFamily == .systemSmall ? 2 : 5)) { conversation in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title)
                            .font(.caption)
                            .lineLimit(1)
                        Text(conversation.updatedAt.timeAgo())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    if conversation.id != entry.conversations.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Quick Chat Widget (Interactive)

struct QuickChatWidget: Widget {
    let kind: String = "QuickChatWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickChatProvider()) { entry in
            QuickChatWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Chat")
        .description("Start a new conversation quickly")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickChatProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickChatEntry {
        QuickChatEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickChatEntry) -> Void) {
        completion(QuickChatEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickChatEntry>) -> Void) {
        let entry = QuickChatEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickChatEntry: TimelineEntry {
    let date: Date
}

struct QuickChatWidgetView: View {
    var entry: QuickChatEntry

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.badge.plus.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("New Chat")
                .font(.headline)

            Button(intent: StartNewChatIntent()) {
                Text("Start")
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Conversation Count Widget (Lock Screen)

struct ConversationCountWidget: Widget {
    let kind: String = "ConversationCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConversationCountProvider()) { entry in
            ConversationCountWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Chat Count")
        .description("Number of conversations")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ConversationCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConversationCountEntry {
        ConversationCountEntry(date: Date(), count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConversationCountEntry) -> Void) {
        let count = HuggingChatSession.shared.conversations.count
        completion(ConversationCountEntry(date: Date(), count: count))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConversationCountEntry>) -> Void) {
        let count = HuggingChatSession.shared.conversations.count
        let entry = ConversationCountEntry(date: Date(), count: count)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
    }
}

struct ConversationCountEntry: TimelineEntry {
    let date: Date
    let count: Int
}

struct ConversationCountWidgetView: View {
    var entry: ConversationCountEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "message.fill")
                        .font(.title3)
                    Text("\(entry.count)")
                        .font(.headline)
                }
            }

        case .accessoryRectangular:
            HStack {
                Image(systemName: "message.fill")
                VStack(alignment: .leading) {
                    Text("Conversations")
                        .font(.caption2)
                    Text("\(entry.count)")
                        .font(.headline)
                }
            }

        case .accessoryInline:
            Text("💬 \(entry.count) chats")

        default:
            EmptyView()
        }
    }
}

// MARK: - Widget Configuration Intent

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Configure widget settings")
}
