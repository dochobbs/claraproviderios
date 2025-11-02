import SwiftUI
import UIKit

struct ClaudeChatView: View {
    @StateObject private var chatService = ClaudeChatService()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showingAPIKeyInput: Bool = false
    @State private var apiKeyInput: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Show API key input if not connected
                if !chatService.isConnected {
                    APIKeyInputView(
                        apiKey: $apiKeyInput,
                        onSave: {
                            chatService.updateAPIKey(apiKeyInput)
                            apiKeyInput = ""
                        }
                    )
                } else {
                    // Messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if messages.isEmpty {
                                    VStack(spacing: 16) {
                                        // Claude icon - try both asset name and direct UIImage
                                        Group {
                                            if let uiImage = UIImage(named: "ClaudeIcon") {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .renderingMode(.original)
                                                    .scaledToFit()
                                                    .frame(width: 64, height: 64)
                                            } else {
                                                Image("ClaudeIcon")
                                                    .resizable()
                                                    .renderingMode(.original)
                                                    .scaledToFit()
                                                    .frame(width: 64, height: 64)
                                            }
                                        }
                                        Text("Chat with Claude")
                                            .font(.rethinkSansBold(22, relativeTo: .title2))
                                        Text("Ask me anything!")
                                            .font(.rethinkSans(17, relativeTo: .body))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding()
                                } else {
                                    ForEach(messages) { message in
                                        ChatBubbleView(message: message)
                                            .id(message.id)
                                    }
                                }
                            
                            if isSending {
                                HStack(alignment: .top, spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryCoral))
                                    Text("Claude is thinking...")
                                        .font(.rethinkSans(15, relativeTo: .subheadline))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("sending")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isSending) { _, newValue in
                        if newValue {
                            withAnimation {
                                proxy.scrollTo("sending", anchor: .bottom)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.adaptiveBackground(for: colorScheme))
                    }
                }
                
                Divider()
                
                // Input area
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("Type your message...")
                                    .font(.rethinkSans(17, relativeTo: .body))
                                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            
                            TextField("", text: $inputText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.rethinkSans(17, relativeTo: .body))
                                .foregroundColor(.black)
                                .padding(12)
                                .frame(minHeight: 44, maxHeight: 120, alignment: .topLeading)
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.adaptiveTertiaryBackground(for: colorScheme), lineWidth: 1)
                        )
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(inputText.isEmpty ? .secondary : .primaryCoral)
                        }
                        .disabled(inputText.isEmpty || isSending)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.adaptiveBackground(for: colorScheme))
            }
            .background(Color.adaptiveBackground(for: colorScheme))
            .navigationTitle("Claude Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !messages.isEmpty {
                        Button(action: {
                            HapticFeedback.light()
                            chatService.resetConversation()
                            messages.removeAll()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.primaryCoral)
                        }
                        .accessibilityLabel("Reset Conversation")
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showingAPIKeyInput) {
                APIKeyInputView(
                    apiKey: $apiKeyInput,
                    onSave: {
                        chatService.updateAPIKey(apiKeyInput)
                        apiKeyInput = ""
                        showingAPIKeyInput = false
                    },
                    onCancel: {
                        apiKeyInput = ""
                        showingAPIKeyInput = false
                    }
                )
            }
            .onAppear {
                // Load existing API key if available
                if let existingKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey"), !existingKey.isEmpty {
                    apiKeyInput = existingKey
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        inputText = ""
        
        // Add user message to UI
        let userMsg = ChatMessage(content: userMessage, isFromUser: true)
        messages.append(userMsg)
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await chatService.sendMessage(userMessage)
                await MainActor.run {
                    let assistantMsg = ChatMessage(content: response, isFromUser: false)
                    messages.append(assistantMsg)
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    // Remove the user message if sending failed
                    if let index = messages.firstIndex(where: { $0.id == userMsg.id }) {
                        messages.remove(at: index)
                    }
                }
            }
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp = Date()
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    @State private var showCopyConfirmation = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.rethinkSans(17, relativeTo: .body))
                    .foregroundColor(message.isFromUser ? .white : Color.adaptiveLabel(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.isFromUser ? Color.primaryCoral : Color.adaptiveSecondaryBackground(for: colorScheme))
                    )
                    .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
                    .frame(maxWidth: 300, alignment: message.isFromUser ? .trailing : .leading)
                    .contextMenu {
                        Button(action: {
                            copyToClipboard()
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    .onLongPressGesture {
                        copyToClipboard()
                    }
                
                if showCopyConfirmation {
                    Text("Copied!")
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.primaryCoral)
                        .transition(.opacity)
                } else {
                    Text(formatTime(message.timestamp))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = message.content
        HapticFeedback.success()
        
        withAnimation {
            showCopyConfirmation = true
        }
        
        // Hide confirmation after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopyConfirmation = false
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    @Binding var apiKey: String
    var onSave: () -> Void
    var onCancel: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Claude icon
                Group {
                    if let uiImage = UIImage(named: "ClaudeIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    } else {
                        Image("ClaudeIcon")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }
                }
                
                VStack(spacing: 12) {
                    Text("Enter Claude API Key")
                        .font(.rethinkSansBold(22, relativeTo: .title2))
                    
                    Text("Your API key will be stored locally on this device")
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.rethinkSansBold(15, relativeTo: .subheadline))
                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                    
                    SecureField("sk-ant-api03-...", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.adaptiveTertiaryBackground(for: colorScheme), lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Button(action: {
                    HapticFeedback.medium()
                    onSave()
                }) {
                    Text("Save API Key")
                        .font(.rethinkSansBold(17, relativeTo: .body))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(apiKey.isEmpty ? Color.gray : Color.primaryCoral)
                        )
                }
                .disabled(apiKey.isEmpty)
                
                Spacer()
            }
            .padding()
            .background(Color.adaptiveBackground(for: colorScheme))
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let onCancel = onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

#Preview {
    ClaudeChatView()
}

