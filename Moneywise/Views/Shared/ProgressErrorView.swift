// ProgressErrorView.swift
import SwiftUI

struct ProgressErrorView: View {
    let isProcessing: Bool
    let errorMessage: String?
    let onDismissError: () -> Void
    
    var body: some View {
        ZStack {
            if isProcessing {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Processing...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(30)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6).opacity(0.9)))
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in onDismissError() }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }
}
