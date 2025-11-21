import Foundation

extension Decimal {
    /// Formats the decimal value as a coin currency string with 💰 emoji
    /// Example: 10000.00 -> "💰 10,000.00"
    var coinFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        let numberString = formatter.string(from: self as NSDecimalNumber) ?? "0.00"
        return "💰 \(numberString)"
    }
}
