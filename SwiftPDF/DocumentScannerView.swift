//
//  DocumentScannerView.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

#if canImport(VisionKit) && os(iOS)
import PDFKit
import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: (Result<PDFDocument, Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onComplete: (Result<PDFDocument, Error>) -> Void

        init(onComplete: @escaping (Result<PDFDocument, Error>) -> Void) {
            self.onComplete = onComplete
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.onComplete(.failure(error))
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pdfDocument = PDFDocument()
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                if let page = PDFPage(image: image) {
                    pdfDocument.insert(page, at: index)
                }
            }
            controller.dismiss(animated: true) {
                if pdfDocument.pageCount > 0 {
                    self.onComplete(.success(pdfDocument))
                } else {
                    self.onComplete(.failure(ScanError.noPages))
                }
            }
        }
    }
}

#endif

enum ScanError: LocalizedError {
    case noPages
    case notSupported

    var errorDescription: String? {
        switch self {
        case .noPages:
            return "No pages were captured."
        case .notSupported:
            return "Document scanning is not available on this device."
        }
    }
}
