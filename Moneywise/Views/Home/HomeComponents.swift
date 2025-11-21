import SwiftUI

struct FloatingButtonBar: View {
    @Binding var showManualSheet: Bool
    @Binding var showAISheet: Bool
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            // Reports Button
            Button(action: {
                selectedTab = .reports
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 20, weight: .medium))
                    Text("Reports".localized)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
            }
            
            // Central AI Button with enhanced styling
            Button(action: {
                showAISheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.6),
                                    Color(red: 0.1, green: 0.6, blue: 0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(red: 0.15, green: 0.65, blue: 0.55).opacity(0.5), radius: 15, x: 0, y: 5)
                    
                    Image(systemName: "brain")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -20)
            .frame(maxWidth: .infinity)
            
            // Goals Button
            Button(action: {
                selectedTab = .goals
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .medium))
                    Text("Goals".localized)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glassmorphism effect
                Color(.systemBackground)
                    .opacity(0.95)
                
                // Top border
                VStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
        .frame(height: 80)
    }
}
