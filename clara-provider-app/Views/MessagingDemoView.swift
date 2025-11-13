import SwiftUI

/// Demo view for bidirectional provider ↔ parent messaging
/// This is a prototype for testing the UI before full backend implementation
struct MessagingDemoView: View {
    @Environment(\.colorScheme) var colorScheme
    let conversationId: UUID
    let patientName: String?

    @State private var messageText: String = ""
    @State private var demoMessages: [DemoMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            if demoMessages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.primaryCoral)
                    Text("Start Messaging")
                        .font(.rethinkSansBold(20, relativeTo: .title3))
                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                    Text("Send a message to \(patientName ?? "the parent") to start a conversation")
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("This is a demo interface. Real messages will be saved to the database.")
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(demoMessages) { message in
                            DemoMessageBubbleView(message: message)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Message input
            HStack(spacing: 12) {
                TextEditor(text: $messageText)
                    .font(.rethinkSans(15, relativeTo: .body))
                    .frame(minHeight: 36, maxHeight: 100)  // ~1 line min, ~4 lines max
                    .padding(8)
                    .scrollContentBackground(.hidden)  // Remove default TextEditor background
                    .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.adaptiveSecondaryLabel(for: colorScheme).opacity(0.3), lineWidth: 1)
                    )

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.adaptiveSecondaryLabel(for: colorScheme) : .primaryCoral)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        }
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .onAppear {
            loadDemoMessages()
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newMessage = DemoMessage(
            id: UUID(),
            content: trimmed,
            isFromProvider: true,
            timestamp: Date(),
            senderName: "You"
        )

        demoMessages.append(newMessage)
        messageText = ""

        HapticFeedback.light()

        // Simulate parent reply after 2 seconds (demo only)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let parentReply = DemoMessage(
                id: UUID(),
                content: "Thank you for following up! This is a demo reply from the parent.",
                isFromProvider: false,
                timestamp: Date(),
                senderName: patientName ?? "Parent"
            )
            demoMessages.append(parentReply)
            HapticFeedback.light()
        }
    }

    private func loadDemoMessages() {
        // No initial messages - let provider start the conversation
        // Empty state will show instructions to send first message
    }
}

// MARK: - Demo Message Bubble View

struct DemoMessageBubbleView: View {
    let message: DemoMessage
    @Environment(\.colorScheme) var colorScheme

    var bubbleColor: Color {
        if message.senderName == "System" {
            return colorScheme == .dark ? Color.orange.opacity(0.3) : Color.orange.opacity(0.15)
        }
        if message.isFromProvider {
            return Color.primaryCoral
        } else {
            return colorScheme == .dark ? Color(.tertiarySystemBackground) : Color.userBubbleBackground
        }
    }

    var textColor: Color {
        if message.isFromProvider {
            return .white
        } else {
            return Color.adaptiveLabel(for: colorScheme)
        }
    }

    var alignment: HorizontalAlignment {
        message.isFromProvider ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack {
                if message.isFromProvider { Spacer() }

                VStack(alignment: .leading, spacing: 4) {
                    if !message.isFromProvider {
                        Text(message.senderName)
                            .font(.rethinkSansBold(12, relativeTo: .caption))
                            .foregroundColor(.secondary)
                    }

                    Text(message.content)
                        .font(.rethinkSans(15, relativeTo: .body))
                        .foregroundColor(textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(bubbleColor)
                        .cornerRadius(16)
                }
                .frame(maxWidth: 280, alignment: alignment == .trailing ? .trailing : .leading)

                if !message.isFromProvider { Spacer() }
            }

            Text(formatTime(message.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Demo Message Model

struct DemoMessage: Identifiable {
    let id: UUID
    let content: String
    let isFromProvider: Bool
    let timestamp: Date
    let senderName: String
}
