import SwiftUI

struct ReviewActionsView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    let reviewId: String
    
    @State private var showingResponseSheet = false
    @State private var showingConfirmDialog = false
    @State private var pendingAction: ActionType? = nil
    
    enum ActionType {
        case flag
        case escalate
        case resolve
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionButton(
                    title: "Flag",
                    icon: "flag.fill",
                    color: .yellow
                ) {
                    pendingAction = .flag
                    showingConfirmDialog = true
                }
                
                ActionButton(
                    title: "Escalate",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    pendingAction = .escalate
                    showingConfirmDialog = true
                }
                
                ActionButton(
                    title: "Respond",
                    icon: "message.fill",
                    color: .primaryCoral
                ) {
                    showingResponseSheet = true
                }
                
                ActionButton(
                    title: "Resolve",
                    icon: "checkmark.circle.fill",
                    color: .green
                ) {
                    pendingAction = .resolve
                    showingConfirmDialog = true
                }
            }
        }
        .padding()
        .background(Color.adaptiveBackground(for: colorScheme))
        .sheet(isPresented: $showingResponseSheet) {
            ProviderResponseView(reviewId: reviewId)
                .environmentObject(store)
        }
        .confirmationDialog(
            "Confirm Action",
            isPresented: $showingConfirmDialog,
            presenting: pendingAction
        ) { action in
            Button(actionTitle(action), role: .destructive) {
                performAction(action)
            }
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: { action in
            Text(actionMessage(action))
        }
    }
    
    private func actionTitle(_ action: ActionType) -> String {
        switch action {
        case .flag:
            return "Flag for Review"
        case .escalate:
            return "Escalate"
        case .resolve:
            return "Mark as Resolved"
        }
    }
    
    private func actionMessage(_ action: ActionType) -> String {
        switch action {
        case .flag:
            return "Flag this conversation for review?"
        case .escalate:
            return "Escalate this conversation as urgent?"
        case .resolve:
            return "Mark this conversation as resolved?"
        }
    }
    
    private func performAction(_ action: ActionType) {
        Task {
            do {
                switch action {
                case .flag:
                    try await store.flagConversation(id: reviewId)
                case .escalate:
                    try await store.escalateConversation(id: reviewId)
                case .resolve:
                    try await store.markAsResolved(id: reviewId)
                }
                
                await MainActor.run {
                    pendingAction = nil
                }
            } catch {
                await MainActor.run {
                    print("Error performing action: \(error)")
                    pendingAction = nil
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.adaptiveSecondaryBackground(for: colorScheme))
            .cornerRadius(8)
        }
    }
}

struct ProviderResponseView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let reviewId: String
    @State private var responseText: String = ""
    @State private var providerName: String = ""
    @State private var urgency: String = "routine"
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Provider Response") {
                    TextEditor(text: $responseText)
                        .frame(minHeight: 150)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
                
                Section("Provider Name") {
                    TextField("Your name (optional)", text: $providerName)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
                
                Section("Urgency Level") {
                    Picker("Urgency", selection: $urgency) {
                        Text("Routine").tag("routine")
                        Text("Urgent").tag("urgent")
                        Text("ER").tag("er")
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
                
                Section {
                    Button(action: submitResponse) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Response")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
                .listRowBackground(Color.adaptiveSecondaryBackground(for: colorScheme))
            }
            .scrollContentBackground(.hidden)
            .background(Color.adaptiveBackground(for: colorScheme))
            .navigationTitle("Provider Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitResponse() {
        guard !responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        Task {
            do {
                try await store.addProviderResponse(
                    id: reviewId,
                    response: responseText,
                    name: providerName.isEmpty ? nil : providerName,
                    urgency: urgency
                )
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("Error submitting response: \(error)")
                }
            }
        }
    }
}
