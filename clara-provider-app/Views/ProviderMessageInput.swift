import SwiftUI

struct ProviderMessageInputView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let conversationId: UUID
    @State private var messageText: String = ""
    @State private var urgency: String = "routine"
    @State private var isSending = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section("Message") {
                    TextEditor(text: $messageText)
                        .font(.rethinkSans(17, relativeTo: .body))
                        .frame(minHeight: 100)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
                
                Section("Urgency") {
                    Picker("Urgency", selection: $urgency) {
                        Text("Routine").tag("routine")
                        Text("Urgent").tag("urgent")
                        Text("ER").tag("er")
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
                
                Section {
                    Button(action: sendMessage) {
                        HStack {
                            if isSending {
                                ProgressView()
                            }
                            Text(isSending ? "Sending..." : "Send Message")
                                .font(.rethinkSansBold(17, relativeTo: .body))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
            }
            .scrollContentBackground(.hidden)
            .background(Color.adaptiveBackground(for: colorScheme))
            .navigationTitle("Send Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                try await store.sendMessage(
                    conversationId: conversationId,
                    content: messageText,
                    urgency: urgency
                )
                
                await MainActor.run {
                    isSending = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
