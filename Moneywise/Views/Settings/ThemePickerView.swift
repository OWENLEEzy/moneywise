import SwiftUI

struct ThemePickerView: View {
    @Environment(\.appTheme) private var theme

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择主题 / Choose Theme")
                .font(.headline)
                .foregroundColor(theme.text)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AppTheme.ThemeOption.allCases) { themeOption in
                    ThemeOptionCard(
                        theme: themeOption,
                        isSelected: theme.currentTheme == themeOption
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            theme.currentTheme = themeOption
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ThemeOptionCard: View {
    let theme: AppTheme.ThemeOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Color preview circle
                ZStack {
                    Circle()
                        .fill(theme.heroGradient)
                        .frame(width: 60, height: 60)

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 68, height: 68)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .background(Circle().fill(theme.primaryColor).padding(4))
                    }
                }

                Text(theme.localizedName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ThemePickerView()
        .environment(\.appTheme, AppTheme())
}
