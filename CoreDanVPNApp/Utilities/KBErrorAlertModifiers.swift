import SwiftUI

extension View {
    func kbErrorAlert(error: Binding<Error?>) -> some View {
        alert(
            "Error",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: {
            Text(error.wrappedValue?.localizedDescription ?? "")
        }
    }

    func kbSuccessAlert(isPresented: Binding<Bool>, title: String) -> some View {
        alert(title, isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        }
    }
}
