import Foundation
import PDFKit
import os

enum PDFMergeService {
    private static let logger = Logger(subsystem: "JimWas.SwiftPDF", category: "PDFMergeService")

    static func merge(urls: [URL]) -> PDFDocument? {
        let mergedDocument = PDFDocument()

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            guard let sourceDoc = PDFDocument(url: url) else {
                logger.error("Skipping unreadable PDF while merging: \(url.lastPathComponent, privacy: .public)")
                continue
            }

            for i in 0..<sourceDoc.pageCount {
                if let page = sourceDoc.page(at: i) {
                    // We must copy the page to avoid ownership issues
                    if let pageCopy = page.copy() as? PDFPage {
                        mergedDocument.insert(pageCopy, at: mergedDocument.pageCount)
                    } else {
                        logger.error("Failed to copy page \(i) from \(url.lastPathComponent, privacy: .public)")
                    }
                }
            }
        }

        return mergedDocument.pageCount > 0 ? mergedDocument : nil
    }
}
