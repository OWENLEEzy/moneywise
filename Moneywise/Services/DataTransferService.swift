//
//  DataTransferService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: CSV import/export service for transaction data
//

import Foundation
import SwiftData

/// # CSVService
///
/// ## Overview
/// Service responsible for importing and exporting transaction data in CSV format.
/// Handles CSV parsing, data validation, duplicate detection, and SwiftData persistence.
/// Supports both full import and deduplication strategies.
///
/// ## Usage
/// ```swift
/// let csvService = CSVService()
///
/// // Export transactions
/// let csvURL = try csvService.export(transactions: myTransactions)
/// // Share csvURL via share sheet
///
/// // Import transactions
/// let result = try csvService.import(
///     url: fileURL,
///     context: modelContext,
///     strategy: .skipDuplicates
/// )
/// print("Imported: \(result.imported), Skipped: \(result.skipped)")
/// ```
///
/// ## Error Handling
/// - `CSVServiceError.invalidFormat`: CSV file is malformed or missing required headers
/// - `CSVServiceError.decodingFailure`: Row data cannot be decoded
/// - SwiftData errors during insert operations
///
/// ## Thread Safety
/// This class is not thread-safe. All operations should be performed on a single thread.
/// When using with SwiftData, ensure proper context usage.
///
/// ## Dependencies
/// - Foundation: FileManager for file operations
/// - SwiftData: ModelContext for transaction persistence
///
/// ## CSV Format
/// Export format (header row required):
/// ```csv
/// date,amount,category,type,note,account,is_ai_generated
/// 2025-01-15T12:30:00Z,30.50,"Food & Dining",expense,"Lunch at cafe","Cash",true
/// ```
///
/// - date: ISO8601 formatted timestamp
/// - amount: Decimal number
/// - category: Category name (quoted if contains commas)
/// - type: "expense" or "income"
/// - note: Transaction note (quoted if contains commas)
/// - account: Account name (quoted if contains commas)
/// - is_ai_generated: boolean ("true" or "false")

/// Errors that can occur during CSV operations
enum CSVServiceError: Error {
    case invalidFormat
    case decodingFailure
}

/// Internal record format for CSV decoding
struct CSVRecord: Codable {
    let date: Date
    let amount: Decimal
    let category: String
    let type: String
    let note: String
    let account: String
    let isAIGenerated: Bool
}

/// Result of an import operation
struct ImportResult {
    let imported: Int  // Number of records successfully imported
    let skipped: Int   // Number of records skipped (duplicates or invalid)
}

/// Import strategy for handling duplicates
enum ImportStrategy {
    case skipDuplicates  // Skip records that match existing transactions
    case importAll       // Import all records regardless of duplicates
}

/// Service for CSV import/export of transaction data
final class CSVService {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return formatter
    }()

    /// Exports transactions to a CSV file
    ///
    /// Creates a temporary CSV file with all transaction data.
    /// The file should be shared or copied promptly as temporary files may be cleaned up.
    ///
    /// - Parameter transactions: Array of transactions to export
    /// - Returns: URL to the temporary CSV file
    /// - Throws: File writing errors
    /// - Note: Generated file has format "Moneywise-{UUID}.csv" in temp directory
    func export(transactions: [Transaction]) throws -> URL {
        let header = "date,amount,category,type,note,account,is_ai_generated\n"
        let rows = transactions.map { transaction in
            let dateString = dateFormatter.string(from: transaction.date)
            let category = transaction.category?.name ?? "Uncategorized"
            let row = [
                dateString,
                "\(transaction.amount)",
                "\"\(category)\"",
                transaction.type.rawValue,
                "\"\(transaction.note)\"",
                "\"\(transaction.account)\"",
                "\(transaction.isAIGenerated)"
            ].joined(separator: ",")
            return row
        }
        let csv = header + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Moneywise-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Imports transactions from a CSV file
    ///
    /// Reads a CSV file, validates format, and creates Transaction records.
    /// Handles quoted values containing commas and optionally skips duplicates.
    ///
    /// ## Import Process
    /// 1. Validates CSV header (must contain "date" column)
    /// 2. Parses each row, handling quoted values
    /// 3. Validates data format (date, amount, type)
    /// 4. Optionally checks for existing duplicates
    /// 5. Creates new Transaction records with category lookup
    /// 6. Saves all changes to context
    ///
    /// - Parameters:
    ///   - url: URL of the CSV file to import
    ///   - context: SwiftData context for inserting transactions
    ///   - strategy: How to handle duplicate records
    /// - Returns: `ImportResult` with counts of imported and skipped records
    /// - Throws: `CSVServiceError` for invalid format, SwiftData errors for persistence
    /// - Note: Categories are looked up by name; new categories are created automatically
    func `import`(url: URL, context: ModelContext, strategy: ImportStrategy) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        guard let csvString = String(data: data, encoding: .utf8) else { throw CSVServiceError.invalidFormat }
        var lines = csvString.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw CSVServiceError.invalidFormat }
        let header = lines.removeFirst()
        guard header.contains("date") else { throw CSVServiceError.invalidFormat }

        var inserted = 0
        var skipped = 0

        for line in lines {
            let columns = parseColumns(line)
            guard columns.count >= 7,
                  let date = dateFormatter.date(from: columns[0]),
                  let amount = Decimal(string: columns[1]) else {
                skipped += 1
                continue
            }
            let note = columns[4]
            if strategy == .skipDuplicates,
               try isDuplicate(amount: amount, note: note, date: date, context: context) {
                skipped += 1
                continue
            }
            let transaction = Transaction(
                amount: amount,
                type: TransactionType(rawValue: columns[3]) ?? .expense,
                category: try? context.category(named: columns[2].trimmingCharacters(in: CharacterSet(charactersIn: "\"")), type: .expense),
                account: columns[5],
                date: date,
                note: note.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
                isAIGenerated: Bool(columns[6]) ?? false
            )
            context.insert(transaction)
            inserted += 1
        }
        context.saveSafe()
        return ImportResult(imported: inserted, skipped: skipped)
    }

    /// Parses a CSV line into columns, handling quoted values
    ///
    /// Correctly handles CSV format where values containing commas are enclosed in quotes.
    /// Example: `"Smith, John",123,Main St` -> ["Smith, John", "123", "Main St"]
    ///
    /// - Parameter line: Raw CSV line string
    /// - Returns: Array of column strings
    /// - Note: Quotes are removed from quoted values; unquoted values are preserved
    private func parseColumns(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                result.append(current)
                current.removeAll()
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    /// Checks if a transaction already exists in the context
    ///
    /// Duplicate detection uses exact match on amount, note, and date.
    /// Uses SwiftData predicate for efficient database-level filtering.
    ///
    /// - Parameters:
    ///   - amount: Transaction amount to check
    ///   - note: Transaction note to check
    ///   - date: Transaction date to check
    ///   - context: SwiftData context for querying
    /// - Returns: true if a matching transaction exists
    /// - Throws: SwiftData fetch errors
    private func isDuplicate(amount: Decimal, note: String, date: Date, context: ModelContext) throws -> Bool {
        let predicate = #Predicate<Transaction> {
            $0.amount == amount && $0.note == note && $0.date == date
        }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        let matches = try context.fetch(descriptor)
        return !matches.isEmpty
    }

}
