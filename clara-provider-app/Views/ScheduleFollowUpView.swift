import SwiftUI

struct ScheduleFollowUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var store: ProviderConversationStore

    let request: ProviderReviewRequestDetail

    @State private var message: String = ""
    @State private var selectedTimeOption: FollowUpTimeOption = .oneHour
    @State private var customDate: Date = Date().addingTimeInterval(3600) // Default to 1 hour from now
    @State private var selectedUrgency: String = "routine"
    @State private var isScheduling: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    enum FollowUpTimeOption: String, CaseIterable {
        case oneHour = "In 1 hour"
        case fourHours = "In 4 hours"
        case tomorrow = "Tomorrow morning (9 AM)"
        case twoDays = "In 2 days"
        case custom = "Custom time"

        func calculateDate() -> Date {
            let now = Date()
            let calendar = Calendar.current

            switch self {
            case .oneHour:
                return now.addingTimeInterval(3600)
            case .fourHours:
                return now.addingTimeInterval(14400)
            case .tomorrow:
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.day! += 1
                components.hour = 9
                components.minute = 0
                return calendar.date(from: components) ?? now.addingTimeInterval(86400)
            case .twoDays:
                return now.addingTimeInterval(172800)
            case .custom:
                return now.addingTimeInterval(3600) // Default
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schedule Follow-up")
                            .font(.rethinkSansBold(24, relativeTo: .title))
                            .foregroundColor(Color.adaptiveLabel(for: colorScheme))

                        if let childName = request.childName {
                            Text("For \(childName)")
                                .font(.rethinkSans(17, relativeTo: .body))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Message Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Message")
                            .font(.rethinkSansBold(17, relativeTo: .headline))
                            .foregroundColor(Color.adaptiveLabel(for: colorScheme))

                        Text("This message will be sent to the parent at the scheduled time.")
                            .font(.rethinkSans(14, relativeTo: .caption))
                            .foregroundColor(.secondary)

                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.adaptiveSecondaryBackground(for: colorScheme))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        if message.count > 500 {
                            Text("\(message.count)/500 characters - Message too long")
                                .font(.rethinkSans(12, relativeTo: .caption2))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Time Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When to send")
                            .font(.rethinkSansBold(17, relativeTo: .headline))
                            .foregroundColor(Color.adaptiveLabel(for: colorScheme))

                        ForEach(FollowUpTimeOption.allCases, id: \.self) { option in
                            Button(action: {
                                HapticFeedback.selection()
                                selectedTimeOption = option
                            }) {
                                HStack {
                                    Image(systemName: selectedTimeOption == option ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedTimeOption == option ? .primaryCoral : .gray)

                                    Text(option.rawValue)
                                        .font(.rethinkSans(16, relativeTo: .body))
                                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }

                        if selectedTimeOption == .custom {
                            DatePicker(
                                "Select time",
                                selection: $customDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .font(.rethinkSans(15, relativeTo: .body))
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Urgency Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Urgency")
                            .font(.rethinkSansBold(17, relativeTo: .headline))
                            .foregroundColor(Color.adaptiveLabel(for: colorScheme))

                        HStack(spacing: 12) {
                            UrgencyButton(title: "Routine", urgency: "routine", selected: $selectedUrgency)
                            UrgencyButton(title: "Urgent", urgency: "urgent", selected: $selectedUrgency)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground(for: colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                    .font(.rethinkSans(17, relativeTo: .body))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: scheduleFollowUp) {
                        if isScheduling {
                            ProgressView()
                        } else {
                            Text("Schedule")
                                .font(.rethinkSansBold(17, relativeTo: .body))
                        }
                    }
                    .disabled(isScheduling || message.isEmpty || message.count > 500)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func scheduleFollowUp() {
        guard !message.isEmpty, message.count <= 500 else { return }

        HapticFeedback.success()
        isScheduling = true

        let scheduledDate = selectedTimeOption == .custom ? customDate : selectedTimeOption.calculateDate()

        // Calculate days/hours/minutes difference
        let interval = scheduledDate.timeIntervalSince(Date())
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        Task {
            do {
                guard let conversationId = UUID(uuidString: request.conversationId) else {
                    throw NSError(domain: "ScheduleFollowUp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid conversation ID"])
                }

                try await store.scheduleFollowUp(
                    conversationId: conversationId,
                    userId: request.userId,
                    childName: request.childName,
                    childAge: request.childAge,
                    scheduledFor: scheduledDate,
                    urgency: selectedUrgency,
                    message: message,
                    followUpDays: days > 0 ? days : nil,
                    followUpHours: hours > 0 ? hours : nil,
                    followUpMinutes: minutes > 0 ? minutes : nil
                )

                await MainActor.run {
                    isScheduling = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isScheduling = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct UrgencyButton: View {
    let title: String
    let urgency: String
    @Binding var selected: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            selected = urgency
        }) {
            Text(title)
                .font(.rethinkSans(16, relativeTo: .body))
                .foregroundColor(selected == urgency ? .white : Color.adaptiveLabel(for: colorScheme))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(selected == urgency ? Color.primaryCoral : Color.adaptiveSecondaryBackground(for: colorScheme))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected == urgency ? Color.primaryCoral : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
