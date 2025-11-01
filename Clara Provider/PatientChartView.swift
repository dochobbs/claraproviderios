import SwiftUI

// This file intentionally forwards to the canonical PatientChartView implementation.
// The previous content with duplicate types (Message, ConversationListView, ConversationDetailView)
// has been removed to fix build errors.

struct PatientChartViewProxy: View {
    let userId: String
    let name: String
    var body: some View {
        PatientChartView(userId: userId, name: name)
    }
}
