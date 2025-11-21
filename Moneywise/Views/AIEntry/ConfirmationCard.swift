// ConfirmationCard.swift
import SwiftUI

struct ConfirmationCard: View {
    let response: GeminiResponse
    let onSave: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Parsed Transaction".localized)
                .font(.headline)
            HStack {
                Text("Amount:".localized)
                Spacer()
                Text(response.amount?.formatted(.currency(code: "USD").locale(LanguageManager.shared.locale)) ?? "-")
            }
            HStack {
                Text("Category:".localized)
                Spacer()
                Text(response.category ?? "-")
            }
            HStack {
                Text("Date:".localized)
                Spacer()
                if let date = response.date {
                    Text(date.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: LanguageManager.shared.locale)))
                } else {
                    Text("-")
                }
            }
            HStack {
                Text("Type:".localized)
                Spacer()
                Text(response.type?.rawValue.capitalized ?? "-")
            }
            HStack {
                Text("Note:".localized)
                Spacer()
                Text(response.note ?? "-")
            }
            HStack {
                Button(action: onEdit) {
                    Text("Edit".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: onSave) {
                    Text("Save".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(radius: 5)
        .padding()
    }
}

// Helper to format amount if needed
extension Double {
    func formattedCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? ""
    }
}
