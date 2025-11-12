//
//  TranscriptionSummaryView.swift
//  HuggingChat-Mac
//
//  Displays the summary of a transcription
//

import SwiftUI

struct TranscriptionSummaryView: View {
    let summary: String
    let transcript: String
    @Binding var isShowing: Bool

    @State private var showFullTranscript = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Transcription Summary")
                    .font(.headline)

                Spacer()

                Button(action: {
                    withAnimation {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            Divider()

            // Summary Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !summary.isEmpty {
                        Text("Summary")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(summary)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Generating summary...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !transcript.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        DisclosureGroup(
                            isExpanded: $showFullTranscript,
                            content: {
                                Text(transcript)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .padding(.top, 8)
                            },
                            label: {
                                Label("Full Transcript", systemImage: "text.alignleft")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)

            // Actions
            HStack {
                Button(action: {
                    copyToClipboard(summary)
                }) {
                    Label("Copy Summary", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(summary.isEmpty)

                Button(action: {
                    copyToClipboard(transcript)
                }) {
                    Label("Copy Transcript", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .disabled(transcript.isEmpty)

                Spacer()
            }
        }
        .padding(20)
        .frame(width: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    TranscriptionSummaryView(
        summary: "This is a sample summary of the meeting discussing the new product features and timeline.",
        transcript: "This is the full transcript of the meeting. It contains all the details that were discussed during the conversation.",
        isShowing: .constant(true)
    )
}
