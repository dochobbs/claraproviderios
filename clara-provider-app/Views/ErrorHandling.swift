import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
                Button("Retry") {
                    errorMessage = nil
                    // Retry action can be passed via closure if needed
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
    }
}

extension View {
    func errorAlert(errorMessage: Binding<String?>) -> some View {
        self.modifier(ErrorAlertModifier(errorMessage: errorMessage))
    }
}
