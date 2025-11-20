import Foundation

enum Prompt {
    static func transaction(text: String) -> String {
        """
        Analyze the following user input and return a JSON object representing the transaction.
        The JSON object should have the following fields: "amount" (number), "type" (string, "expense" or "income"), "category" (string), "account" (string), "paymentMethod" (string), "note" (string), "confidence" (number, 0-1), and "date" (string, ISO8601 format).
        User input: "\(text)"
        """
    }

    static func analysis(question: String, dataset: String) -> String {
        """
        You are a friendly financial assistant. Please provide a specific analysis and suggestions based on the following billing data. Your tone should be empathetic and avoid lecturing.
        Data: \(dataset)
        User question: \(question)
        """
    }
    
    static func insight(period: String, dataset: String) -> String {
        """
        Analyze the following transaction data for the \(period) and return a JSON object with two fields:
        1. "summary": A brief summary of the spending behavior (max 2 sentences).
        2. "insights": An array of 2-3 short, specific insights or suggestions (e.g., "Spent 30% more on dining out", "Subscription costs are high").
        
        Data:
        \(dataset)
        """
    }
}
