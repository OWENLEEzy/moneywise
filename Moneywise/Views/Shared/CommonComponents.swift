import SwiftUI

struct ToastView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .foregroundColor(.white)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        onDismiss()
                    }
                }
            }
    }
}
