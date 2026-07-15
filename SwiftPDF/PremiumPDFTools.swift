import CoreGraphics
import Foundation
import PDFKit
import UIKit

enum PremiumPDFToolError: LocalizedError {
    case unreadablePDF
    case lockedPDF
    case notEncrypted
    case incorrectPassword
    case passwordTooShort
    case repairFailed
    case exportFailed
    case noText

    var errorDescription: String? {
        switch self {
        case .unreadablePDF: "The selected file is not a readable PDF."
        case .lockedPDF: "This PDF is protected with a password. Unlock it before using this tool."
        case .notEncrypted: "This PDF does not have password security to remove."
        case .incorrectPassword: "The password is incorrect or does not grant permission to unlock this PDF."
        case .passwordTooShort: "Use a password containing at least six characters."
        case .repairFailed: "No readable pages could be recovered from this PDF. Severe file damage may require the original source document."
        case .exportFailed: "SwiftPDF could not create the processed PDF."
        case .noText: "No text could be extracted from this PDF."
        }
    }
}

struct PDFRepairResult {
    let data: Data
    let recoveredPages: Int
}

enum PDFMarkdownService {
    static func convert(data: Data) async throws -> Data {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw PremiumPDFToolError.unreadablePDF
        }
        guard !document.isLocked else { throw PremiumPDFToolError.lockedPDF }

        var sections: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                let bounds = page.bounds(for: .mediaBox)
                let image = page.thumbnail(
                    of: CGSize(width: min(bounds.width * 2, 2_400), height: min(bounds.height * 2, 3_200)),
                    for: .mediaBox
                )
                text = (try? await OCRService.recognizeText(in: image)) ?? ""
            }
            guard !text.isEmpty else { continue }
            let markdown = MarkdownFormatter.format(text)
            sections.append("<!-- Page \(index + 1) -->\n\n\(markdown)")
        }

        guard !sections.isEmpty else { throw PremiumPDFToolError.noText }
        let output = sections.joined(separator: "\n\n---\n\n") + "\n"
        guard let data = output.data(using: .utf8) else { throw PremiumPDFToolError.exportFailed }
        return data
    }
}

enum PDFRepairService {
    static func repair(data: Data) throws -> PDFRepairResult {
        if let document = PDFDocument(data: data), document.pageCount > 0 {
            guard !document.isLocked else { throw PremiumPDFToolError.lockedPDF }
            let rebuilt = PDFDocument()
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                rebuilt.insert(page, at: rebuilt.pageCount)
            }
            if rebuilt.pageCount > 0, let output = rebuilt.dataRepresentation() {
                return PDFRepairResult(data: output, recoveredPages: rebuilt.pageCount)
            }
        }

        // PDFKit can reject a damaged cross-reference table even when Core Graphics
        // can still render individual pages. Rewriting those pages recovers the
        // readable visual content into a clean PDF container.
        guard let provider = CGDataProvider(data: data as CFData),
              let source = CGPDFDocument(provider),
              source.numberOfPages > 0 else {
            throw PremiumPDFToolError.repairFailed
        }

        let first = source.page(at: 1)?.getBoxRect(.mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: first)
        let output = renderer.pdfData { context in
            for index in 1...source.numberOfPages {
                guard let page = source.page(at: index) else { continue }
                var bounds = page.getBoxRect(.mediaBox)
                bounds.origin = .zero
                context.beginPage(withBounds: bounds, pageInfo: [:])
                let cg = context.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: bounds.height)
                cg.scaleBy(x: 1, y: -1)
                cg.drawPDFPage(page)
                cg.restoreGState()
            }
        }
        guard !output.isEmpty else { throw PremiumPDFToolError.repairFailed }
        return PDFRepairResult(data: output, recoveredPages: source.numberOfPages)
    }
}

enum PDFSecurityService {
    struct UnlockResult {
        let data: Data
        let wasEncrypted: Bool
    }

    static func unlock(data: Data, password: String) throws -> UnlockResult {
        guard let document = PDFDocument(data: data), document.pageCount > 0 || document.isEncrypted else {
            throw PremiumPDFToolError.unreadablePDF
        }
        guard document.isEncrypted else { throw PremiumPDFToolError.notEncrypted }
        guard !password.isEmpty, document.unlock(withPassword: password), !document.isLocked else {
            throw PremiumPDFToolError.incorrectPassword
        }

        let rebuilt = PDFDocument()
        for index in 0..<document.pageCount {
            if let page = document.page(at: index)?.copy() as? PDFPage {
                rebuilt.insert(page, at: rebuilt.pageCount)
            }
        }
        guard rebuilt.pageCount > 0,
              let output = rebuilt.dataRepresentation(),
              PDFDocument(data: output)?.isEncrypted == false else {
            throw PremiumPDFToolError.exportFailed
        }
        return UnlockResult(data: output, wasEncrypted: true)
    }

    static func protect(data: Data, password: String) throws -> Data {
        guard password.count >= 6 else { throw PremiumPDFToolError.passwordTooShort }
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw PremiumPDFToolError.unreadablePDF
        }
        guard !document.isLocked else { throw PremiumPDFToolError.lockedPDF }

        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: password,
            .ownerPasswordOption: password
        ]
        guard let output = document.dataRepresentation(options: options),
              PDFDocument(data: output)?.isEncrypted == true else {
            throw PremiumPDFToolError.exportFailed
        }
        return output
    }
}

private enum MarkdownFormatter {
    static func format(_ text: String) -> String {
        let rawLines = text.components(separatedBy: .newlines)
        var output: [String] = []
        var index = 0

        while index < rawLines.count {
            let line = rawLines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if output.last?.isEmpty == false { output.append("") }
                index += 1
                continue
            }

            let tableRows = consecutiveTableRows(from: rawLines, startingAt: index)
            if tableRows.count >= 2 {
                output.append(markdownTable(tableRows))
                index += tableRows.count
                continue
            }

            let linked = linkify(line)
            if let listItem = normalizedListItem(linked) {
                output.append(listItem)
            } else if looksLikeHeading(line, previousLineIsBlank: index == 0 || rawLines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty) {
                output.append("## \(linked)")
            } else {
                output.append(linked)
            }
            index += 1
        }

        return output.joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeHeading(_ line: String, previousLineIsBlank: Bool) -> Bool {
        guard previousLineIsBlank, line.count <= 90, line.count >= 2 else { return false }
        guard !line.hasSuffix("."), !line.hasSuffix(","), !line.hasSuffix(";") else { return false }
        let letters = line.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        let upperRatio = Double(letters.filter(\.isUppercase).count) / Double(letters.count)
        let words = line.split(separator: " ")
        let titleCaseWords = words.filter { $0.first?.isUppercase == true }.count
        return upperRatio > 0.65 || (words.count <= 10 && titleCaseWords >= max(1, words.count / 2))
    }

    private static func normalizedListItem(_ line: String) -> String? {
        let bulletPrefixes = ["• ", "● ", "◦ ", "▪ ", "– ", "— "]
        for prefix in bulletPrefixes where line.hasPrefix(prefix) {
            return "- " + line.dropFirst(prefix.count)
        }
        if line.range(of: #"^\s*\d+[\.)]\s+"#, options: .regularExpression) != nil {
            return line.replacingOccurrences(of: #"^\s*(\d+)[\.)]\s+"#, with: "$1. ", options: .regularExpression)
        }
        return nil
    }

    private static func consecutiveTableRows(from lines: [String], startingAt start: Int) -> [[String]] {
        var rows: [[String]] = []
        var index = start
        while index < lines.count {
            let cells = lines[index]
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: try! NSRegularExpression(pattern: #"\s{2,}"#))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard cells.count >= 2 else { break }
            if let first = rows.first, abs(first.count - cells.count) > 1 { break }
            rows.append(cells)
            index += 1
        }
        return rows
    }

    private static func markdownTable(_ rows: [[String]]) -> String {
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 1 else { return rows.flatMap { $0 }.joined(separator: "\n") }
        func normalized(_ row: [String]) -> [String] {
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }
        var lines = ["| " + normalized(rows[0]).map(escapeTableCell).joined(separator: " | ") + " |"]
        lines.append("| " + Array(repeating: "---", count: columnCount).joined(separator: " | ") + " |")
        for row in rows.dropFirst() {
            lines.append("| " + normalized(row).map(escapeTableCell).joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n")
    }

    nonisolated private static func escapeTableCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }

    private static func linkify(_ line: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return line }
        let range = NSRange(line.startIndex..., in: line)
        var result = line
        for match in detector.matches(in: line, range: range).reversed() {
            guard let swiftRange = Range(match.range, in: result), let url = match.url else { continue }
            let visible = String(result[swiftRange])
            if visible.hasPrefix("[") { continue }
            result.replaceSubrange(swiftRange, with: "[\(visible)](\(url.absoluteString))")
        }
        return result
    }
}

private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        let fullRange = NSRange(startIndex..., in: self)
        var results: [String] = []
        var location = fullRange.location
        for match in regex.matches(in: self, range: fullRange) {
            let range = NSRange(location: location, length: match.range.location - location)
            if let swiftRange = Range(range, in: self) { results.append(String(self[swiftRange])) }
            location = match.range.location + match.range.length
        }
        let tail = NSRange(location: location, length: fullRange.location + fullRange.length - location)
        if let swiftRange = Range(tail, in: self) { results.append(String(self[swiftRange])) }
        return results
    }
}
