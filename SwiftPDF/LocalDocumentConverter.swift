import Foundation
import PDFKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ZIPFoundation

enum LocalDocumentType {
    static let docx = UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    static let xlsx = UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet")
    static let legacyWord = UTType(importedAs: "com.microsoft.word.doc")
    static let legacyExcel = UTType(importedAs: "com.microsoft.excel.xls")
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
    static let zip = UTType(filenameExtension: "zip") ?? .data
}

struct ConvertedFileDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.data, .pdf, .jpeg, LocalDocumentType.docx, LocalDocumentType.markdown, LocalDocumentType.zip]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum PDFCompressionQuality: String, CaseIterable, Identifiable {
    case maximum = "Maximum Quality"
    case balanced = "Balanced"
    case smallest = "Smallest File"

    var id: Self { self }

    fileprivate var dpi: CGFloat {
        switch self {
        case .maximum: 160
        case .balanced: 120
        case .smallest: 90
        }
    }

    fileprivate var jpegQuality: CGFloat {
        switch self {
        case .maximum: 0.84
        case .balanced: 0.72
        case .smallest: 0.56
        }
    }

    var detail: String {
        switch self {
        case .maximum: "Best visual quality with moderate size reduction."
        case .balanced: "A practical balance of clarity and file size."
        case .smallest: "Stronger compression for sharing and storage."
        }
    }
}

struct PDFCompressionResult {
    let data: Data
    let originalBytes: Int
    let compressedBytes: Int

    var savedFraction: Double {
        guard originalBytes > 0 else { return 0 }
        return max(0, 1 - Double(compressedBytes) / Double(originalBytes))
    }

    var usedOriginal: Bool { compressedBytes >= originalBytes }
}

enum LocalConversionError: LocalizedError {
    case invalidPDF
    case unsupportedLegacyFormat(String)
    case unreadableOfficeDocument
    case noConvertibleContent
    case archiveFailure

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            "The selected file is not a readable PDF."
        case .unsupportedLegacyFormat(let ext):
            "The legacy .\(ext) format cannot be converted reliably on your device. Open it in Microsoft Office and save it as .\(ext == "doc" ? "docx" : "xlsx"), then try again."
        case .unreadableOfficeDocument:
            "The Office document could not be read. It may be protected with a password, damaged, or use an unsupported format."
        case .noConvertibleContent:
            "No convertible text or spreadsheet cells were found in this document."
        case .archiveFailure:
            "SwiftPDF could not create the converted document."
        }
    }
}

enum PDFCompressionService {
    static func compress(data: Data, quality: PDFCompressionQuality) throws -> PDFCompressionResult {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw LocalConversionError.invalidPDF
        }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "SwiftPDF",
            kCGPDFContextTitle as String: document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? "Compressed PDF"
        ]

        let firstBounds = document.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds, format: format)
        let output = renderer.pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                var pageBounds = page.bounds(for: .mediaBox)
                if page.rotation == 90 || page.rotation == 270 {
                    pageBounds.size = CGSize(width: pageBounds.height, height: pageBounds.width)
                }
                pageBounds.origin = .zero

                context.beginPage(withBounds: pageBounds, pageInfo: [:])

                let scale = quality.dpi / 72
                let targetSize = cappedSize(
                    CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale),
                    maximumDimension: quality == .maximum ? 3_400 : 2_800
                )
                let thumbnail = page.thumbnail(of: targetSize, for: .mediaBox)
                guard let jpeg = thumbnail.jpegData(compressionQuality: quality.jpegQuality),
                      let compressedImage = UIImage(data: jpeg) else {
                    thumbnail.draw(in: pageBounds)
                    continue
                }
                compressedImage.draw(in: pageBounds)
            }
        }

        // Recompression can make already-optimized/vector-only PDFs larger. In that
        // case, preserve the original rather than claiming a reduction that did not occur.
        let finalData = output.count < data.count ? output : data
        return PDFCompressionResult(
            data: finalData,
            originalBytes: data.count,
            compressedBytes: finalData.count
        )
    }

    private static func cappedSize(_ size: CGSize, maximumDimension: CGFloat) -> CGSize {
        let largest = max(size.width, size.height)
        guard largest > maximumDimension else { return size }
        let ratio = maximumDimension / largest
        return CGSize(width: size.width * ratio, height: size.height * ratio)
    }
}

enum PDFToWordService {
    static func convert(data: Data) async throws -> Data {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw LocalConversionError.invalidPDF
        }

        var pages: [String] = []
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
            pages.append(text)
        }

        guard pages.contains(where: { !$0.isEmpty }) else {
            throw LocalConversionError.noConvertibleContent
        }
        return try DOCXWriter.makeDocument(pages: pages)
    }
}

enum OfficeToPDFService {
    static func convertWord(data: Data, fileExtension: String) throws -> Data {
        guard fileExtension.lowercased() == "docx" else {
            throw LocalConversionError.unsupportedLegacyFormat("doc")
        }
        let directory = try unzipOfficeData(data, extension: "docx")
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let documentXML = directory.appendingPathComponent("word/document.xml")
        guard let xmlData = try? Data(contentsOf: documentXML) else {
            throw LocalConversionError.unreadableOfficeDocument
        }
        let parser = WordTextParser()
        guard parser.parse(xmlData), !parser.paragraphs.isEmpty else {
            throw LocalConversionError.noConvertibleContent
        }

        let body = parser.paragraphs.map { paragraph in
            paragraph.isEmpty ? "<p><br></p>" : "<p>\(paragraph.htmlEscaped)</p>"
        }.joined(separator: "\n")
        return HTMLPDFRenderer.render(body: body, title: "Word Document")
    }

    static func convertExcel(data: Data, fileExtension: String) throws -> Data {
        guard fileExtension.lowercased() == "xlsx" else {
            throw LocalConversionError.unsupportedLegacyFormat("xls")
        }
        let directory = try unzipOfficeData(data, extension: "xlsx")
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let sharedStringsURL = directory.appendingPathComponent("xl/sharedStrings.xml")
        let sharedStrings: [String]
        if let sharedData = try? Data(contentsOf: sharedStringsURL) {
            let parser = SharedStringsParser()
            _ = parser.parse(sharedData)
            sharedStrings = parser.strings
        } else {
            sharedStrings = []
        }

        let sheetsDirectory = directory.appendingPathComponent("xl/worksheets")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sheetsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            throw LocalConversionError.unreadableOfficeDocument
        }
        let sheetFiles = files
            .filter { $0.pathExtension.lowercased() == "xml" && $0.lastPathComponent.hasPrefix("sheet") }
            .sorted { naturalSheetNumber($0.lastPathComponent) < naturalSheetNumber($1.lastPathComponent) }

        var sections: [String] = []
        for (index, file) in sheetFiles.enumerated() {
            guard let sheetData = try? Data(contentsOf: file) else { continue }
            let parser = WorksheetParser(sharedStrings: sharedStrings)
            guard parser.parse(sheetData), !parser.rows.isEmpty else { continue }
            let rows = parser.rows.map { row in
                let cells = row.map { "<td>\($0.htmlEscaped)</td>" }.joined()
                return "<tr>\(cells)</tr>"
            }.joined(separator: "\n")
            sections.append("<h2>Sheet \(index + 1)</h2><table>\(rows)</table>")
        }

        guard !sections.isEmpty else { throw LocalConversionError.noConvertibleContent }
        return HTMLPDFRenderer.render(body: sections.joined(separator: "<div class='pagebreak'></div>"), title: "Excel Workbook")
    }

    private static func unzipOfficeData(_ data: Data, extension ext: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPDF-Office-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = root.appendingPathExtension(ext)
        let destination = root.appendingPathComponent("Expanded", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: archiveURL, options: .atomic)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: archiveURL, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw LocalConversionError.unreadableOfficeDocument
        }
    }

    private static func naturalSheetNumber(_ name: String) -> Int {
        Int(name.filter(\.isNumber)) ?? .max
    }
}

private enum DOCXWriter {
    static func makeDocument(pages: [String]) throws -> Data {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPDF-DOCX-\(UUID().uuidString)", isDirectory: true)
        let output = root.appendingPathExtension("docx")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: output)
        }

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: root.appendingPathComponent("_rels"), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: root.appendingPathComponent("word"), withIntermediateDirectories: true)

            let contentTypes = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
              <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
            </Types>
            """
            let relationships = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
            </Relationships>
            """
            let styles = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/></w:rPr></w:style>
            </w:styles>
            """
            let document = documentXML(pages: pages)

            try contentTypes.write(to: root.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
            try relationships.write(to: root.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
            try styles.write(to: root.appendingPathComponent("word/styles.xml"), atomically: true, encoding: .utf8)
            try document.write(to: root.appendingPathComponent("word/document.xml"), atomically: true, encoding: .utf8)
            try FileManager.default.zipItem(at: root, to: output, shouldKeepParent: false, compressionMethod: .deflate)
            return try Data(contentsOf: output)
        } catch {
            throw LocalConversionError.archiveFailure
        }
    }

    private static func documentXML(pages: [String]) -> String {
        var body = ""
        for (pageIndex, page) in pages.enumerated() {
            let lines = page.components(separatedBy: .newlines)
            for line in lines {
                if line.isEmpty {
                    body += "<w:p/>"
                } else {
                    body += "<w:p><w:r><w:t xml:space=\"preserve\">\(line.xmlEscaped)</w:t></w:r></w:p>"
                }
            }
            if pageIndex < pages.count - 1 {
                body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>\(body)<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr></w:body>
        </w:document>
        """
    }
}

private enum HTMLPDFRenderer {
    static func render(body: String, title: String) -> Data {
        let html = """
        <html><head><meta charset="utf-8"><style>
        @page { margin: 0; }
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 11pt; line-height: 1.35; color: #111; }
        p { margin: 0 0 8pt 0; white-space: pre-wrap; }
        h2 { font-size: 16pt; margin: 0 0 12pt; }
        table { width: 100%; border-collapse: collapse; font-size: 8.5pt; margin-bottom: 18pt; }
        td { border: 0.5pt solid #999; padding: 4pt; vertical-align: top; }
        .pagebreak { page-break-before: always; }
        </style></head><body>\(body)</body></html>
        """
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let paper = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printable = paper.insetBy(dx: 36, dy: 36)
        renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: 1))

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paper, [kCGPDFContextTitle as String: title])
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

private final class WordTextParser: NSObject, XMLParserDelegate {
    private(set) var paragraphs: [String] = []
    private var currentParagraph = ""
    private var currentText = ""
    private var capturingText = false

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "p" { currentParagraph = "" }
        if name == "t" { currentText = ""; capturingText = true }
        if name == "tab" { currentParagraph += "\t" }
        if name == "br" { currentParagraph += "\n" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingText { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "t" {
            currentParagraph += currentText
            capturingText = false
        } else if name == "p" {
            paragraphs.append(currentParagraph)
        }
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private(set) var strings: [String] = []
    private var current = ""
    private var inItem = false
    private var inText = false

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "si" { current = ""; inItem = true }
        if name == "t", inItem { inText = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "t" { inText = false }
        if name == "si" { strings.append(current); inItem = false }
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private(set) var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentCellType: String?
    private var currentCellReference = ""
    private var currentValue = ""
    private var capturingValue = false
    private var lastColumn = -1

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "row" {
            currentRow = []
            lastColumn = -1
        } else if name == "c" {
            currentCellType = attributeDict["t"]
            currentCellReference = attributeDict["r"] ?? ""
            currentValue = ""
        } else if name == "v" || name == "t" {
            capturingValue = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingValue { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "v" || name == "t" {
            capturingValue = false
        } else if name == "c" {
            let column = columnIndex(from: currentCellReference)
            if column > lastColumn + 1 {
                currentRow.append(contentsOf: repeatElement("", count: column - lastColumn - 1))
            }
            let value: String
            if currentCellType == "s", let index = Int(currentValue), sharedStrings.indices.contains(index) {
                value = sharedStrings[index]
            } else if currentCellType == "b" {
                value = currentValue == "1" ? "TRUE" : "FALSE"
            } else {
                value = currentValue
            }
            currentRow.append(value)
            lastColumn = max(lastColumn, column)
        } else if name == "row" {
            rows.append(currentRow)
        }
    }

    private func columnIndex(from reference: String) -> Int {
        let letters = reference.prefix(while: { $0.isLetter }).uppercased()
        var result = 0
        for scalar in letters.unicodeScalars {
            result = result * 26 + Int(scalar.value - 64)
        }
        return max(0, result - 1)
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    var htmlEscaped: String { xmlEscaped }
}
