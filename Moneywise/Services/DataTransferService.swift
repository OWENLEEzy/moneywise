import Foundation
import SwiftData

enum CSVServiceError: Error {
    case invalidFormat
    case decodingFailure
}

struct CSVRecord: Codable {
    let date: Date
    let amount: Decimal
    let category: String
    let type: String
    let note: String
    let account: String
    let isAIGenerated: Bool
}

final class CSVService {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return formatter
    }()

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
        try context.save()
        return ImportResult(imported: inserted, skipped: skipped)
    }

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

    private func isDuplicate(amount: Decimal, note: String, date: Date, context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Transaction>()
        let matches = try context.fetch(descriptor).filter {
            $0.amount == amount && $0.note == note && $0.date == date
        }
        return !matches.isEmpty
    }

}

struct ImportResult {
    let imported: Int
    let skipped: Int
}

enum ImportStrategy {
    case skipDuplicates
    case importAll
}

