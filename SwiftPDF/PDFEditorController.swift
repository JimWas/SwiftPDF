//
//  PDFEditorController.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import Foundation
import PDFKit
import PencilKit
import SwiftUI
import Combine

enum EditorTool {
    case draw
    case text
    case correctText
    case identifyFont
}

struct FontIdentificationResult: Identifiable, Sendable {
    let id = UUID()
    let detectedName: String
    let closestFamily: TextFontFamily
    let size: CGFloat
    let bold: Bool
    let italic: Bool
    let isEmbeddedFont: Bool
    var matchFound = true
}

enum DrawingToolType: String, CaseIterable {
    case pen = "pencil.tip"
    case marker = "highlighter"
    case eraser = "eraser"
}

enum TextFontFamily: String, CaseIterable, Sendable {
    case system = "System"
    case helvetica = "Helvetica"
    case arial = "Arial"
    case timesNewRoman = "Times New Roman"
    case georgia = "Georgia"
    case avenir = "Avenir Next"
    case futura = "Futura"
    case courier = "Courier"
    case serif = "Serif"
    case rounded = "Rounded"
    case mono = "Mono"
}

enum ShapeType: String, CaseIterable {
    case rectangle = "square"
    case circle = "circle"
    case line = "line.diagonal"
    case arrow = "arrow.up.right"

    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .line: return "Line"
        case .arrow: return "Arrow"
        }
    }
}

struct PageDrawing {
    var drawing: PKDrawing
    var canvasSize: CGSize
}

@MainActor
final class PDFEditorController: ObservableObject {
    @Published var document: PDFDocument?
    @Published var activeTool: EditorTool = .draw
    @Published var drawingTool: DrawingToolType = .pen
    @Published var selectedColor: Color = .black
    @Published var textColor: Color = .black
    @Published var correctionBackgroundColor: Color = .white
    @Published var textSize: CGFloat = 16
    @Published var textFontFamily: TextFontFamily = .system
    @Published var textBold = false
    @Published var textItalic = false
    @Published var textStrikethrough = false
    @Published var isDrawingActive = false
    @Published var currentPageIndex = 0
    @Published var fileName = ""
    @Published var sourceURL: URL?
    @Published var drawingVersion = 0
    @Published var isPerformingOCR = false
    @Published var extractedText: String?
    @Published var showingSignatureLibrary = false
    @Published var showingSignaturePad = false
    @Published var showingPageManager = false
    @Published var showingImagePicker = false
    @Published var showingPaywall = false
    @Published var showingShapePicker = false
    @Published var showingProfileEditor = false
    @Published var showingWatermarkEditor = false
    @Published var exportCompressionQuality: CGFloat = 1.0
    @Published var hasSelectedEditableObject = false
    @Published var selectedEditableObjectLabel = ""
    @Published var isIdentifyingFont = false
    @Published var fontIdentificationResult: FontIdentificationResult?

    let signatureStore = SignatureStore()
    let profileStore = UserProfileStore.shared

    var onSyncDrawing: (() -> Void)?
    var onApplyDrawing: ((PKDrawing) -> Void)?
    var onUpdateTool: (() -> Void)?
    var onDeleteSelectedEditableObject: (() -> Void)?
    var onDeselectEditableObject: (() -> Void)?
    var onApplyTextStyleToSelectedObject: (() -> Void)?
    var onSelectTextAnnotation: ((PDFAnnotation, Int) -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onFitPage: (() -> Void)?

    struct InsertedImage {
        let id: UUID
        let image: UIImage
        var bounds: CGRect
        var label: String

        init(id: UUID = UUID(), image: UIImage, bounds: CGRect, label: String = "Image") {
            self.id = id
            self.image = image
            self.bounds = bounds
            self.label = label
        }
    }

    private var drawingsByPage: [Int: PageDrawing] = [:]
    private var imagesByPage: [Int: [InsertedImage]] = [:]
    private var currentCanvasSize: CGSize = .zero

    func load(document: PDFDocument, fileName: String, sourceURL: URL? = nil) {
        self.document = document
        self.fileName = fileName
        self.sourceURL = sourceURL
        activeTool = .draw
        drawingTool = .pen
        selectedColor = .black
        textColor = .black
        correctionBackgroundColor = .white
        textSize = 16
        textFontFamily = .system
        textBold = false
        textItalic = false
        textStrikethrough = false
        isDrawingActive = false
        currentPageIndex = 0
        drawingsByPage = [:]
        imagesByPage = [:]
        drawingVersion = 0
        currentCanvasSize = .zero
        isPerformingOCR = false
        extractedText = nil
        isIdentifyingFont = false
        fontIdentificationResult = nil
        showingSignatureLibrary = false
        showingSignaturePad = false
        showingPageManager = false
        showingImagePicker = false
        showingPaywall = false
        showingShapePicker = false
        showingProfileEditor = false
        showingWatermarkEditor = false
        exportCompressionQuality = 1.0
        clearEditableObjectSelection()
    }

    func reset() {
        document = nil
        fileName = ""
        sourceURL = nil
        activeTool = .draw
        drawingTool = .pen
        selectedColor = .black
        textColor = .black
        correctionBackgroundColor = .white
        textSize = 16
        textFontFamily = .system
        textBold = false
        textItalic = false
        textStrikethrough = false
        isDrawingActive = false
        currentPageIndex = 0
        drawingsByPage = [:]
        imagesByPage = [:]
        drawingVersion = 0
        currentCanvasSize = .zero
        isPerformingOCR = false
        extractedText = nil
        isIdentifyingFont = false
        fontIdentificationResult = nil
        showingSignatureLibrary = false
        showingSignaturePad = false
        showingPageManager = false
        showingImagePicker = false
        showingPaywall = false
        showingShapePicker = false
        showingProfileEditor = false
        showingWatermarkEditor = false
        exportCompressionQuality = 1.0
        clearEditableObjectSelection()
    }

    func setDrawing(_ drawing: PKDrawing, canvasSize: CGSize, forPage index: Int) {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.drawingsByPage[index] = PageDrawing(drawing: drawing, canvasSize: canvasSize)
            self.drawingVersion += 1
        }
    }

    func updateCurrentCanvasSize(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite else { return }
        guard size.width > 0, size.height > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentCanvasSize = size
        }
    }

    func drawing(forPage index: Int) -> PageDrawing? {
        drawingsByPage[index]
    }

    func allDrawings() -> [Int: PageDrawing] {
        drawingsByPage
    }

    func allImages() -> [Int: [InsertedImage]] {
        imagesByPage
    }

    func images(forPage index: Int) -> [InsertedImage] {
        imagesByPage[index] ?? []
    }

    func syncCurrentDrawing() {
        onSyncDrawing?()
    }

    func applyDrawing(_ drawing: PKDrawing) {
        DispatchQueue.main.async { [weak self] in
            self?.onApplyDrawing?(drawing)
            self?.drawingVersion += 1
        }
    }

    func setTool(_ tool: EditorTool) {
        activeTool = tool
        if tool == .text || tool == .correctText || tool == .identifyFont {
            isDrawingActive = false
        }
        clearEditableObjectSelection()
    }

    func applyFontIdentification(_ result: FontIdentificationResult) {
        textFontFamily = result.closestFamily
        textSize = result.size
        textBold = result.bold
        textItalic = result.italic
        applyTextStyleToSelectedObject()
    }

    func zoomIn() {
        onZoomIn?()
    }

    func zoomOut() {
        onZoomOut?()
    }

    func fitPage() {
        onFitPage?()
    }

    func setDrawingTool(_ tool: DrawingToolType) {
        if isDrawingActive && activeTool == .draw && drawingTool == tool {
            syncCurrentDrawing()
            isDrawingActive = false
            clearEditableObjectSelection()
            return
        }

        drawingTool = tool
        isDrawingActive = true
        activeTool = .draw
        clearEditableObjectSelection()
        onUpdateTool?()
    }

    func setColor(_ color: Color) {
        selectedColor = color
        onUpdateTool?()
    }

    func toggleDrawing() {
        activeTool = .draw
        clearEditableObjectSelection()
        let shouldSync = isDrawingActive
        isDrawingActive.toggle()
        if shouldSync {
            DispatchQueue.main.async { [weak self] in
                self?.onSyncDrawing?()
            }
        }
    }

    func undoLastStroke() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard var record = self.drawingsByPage[self.currentPageIndex] else { return }
            var strokes = record.drawing.strokes
            guard !strokes.isEmpty else { return }
            strokes.removeLast()
            let updated = PKDrawing(strokes: strokes)
            record.drawing = updated
            self.drawingsByPage[self.currentPageIndex] = record
            self.onApplyDrawing?(updated)
            self.drawingVersion += 1
        }
    }

    func clearCurrentDrawing() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let empty = PKDrawing()
            let size = self.currentCanvasSize.width > 0 ? self.currentCanvasSize : (self.drawingsByPage[self.currentPageIndex]?.canvasSize ?? .zero)
            if size.width > 0, size.height > 0 {
                self.drawingsByPage[self.currentPageIndex] = PageDrawing(drawing: empty, canvasSize: size)
            } else {
                self.drawingsByPage[self.currentPageIndex] = PageDrawing(drawing: empty, canvasSize: CGSize(width: 1, height: 1))
            }
            self.onApplyDrawing?(empty)
            self.drawingVersion += 1
        }
    }

    func canUndoCurrentPage() -> Bool {
        guard let record = drawingsByPage[currentPageIndex] else { return false }
        return !record.drawing.strokes.isEmpty
    }

    func hasDrawingOnCurrentPage() -> Bool {
        guard let record = drawingsByPage[currentPageIndex] else { return false }
        return !record.drawing.strokes.isEmpty
    }

    // MARK: - Page Management

    func goToPage(_ index: Int) {
        guard let document else { return }
        let clamped = min(max(index, 0), max(document.pageCount - 1, 0))
        guard clamped != currentPageIndex else { return }
        syncCurrentDrawing()
        currentPageIndex = clamped
        clearEditableObjectSelection()
    }

    func goToPreviousPage() {
        goToPage(currentPageIndex - 1)
    }

    func goToNextPage() {
        goToPage(currentPageIndex + 1)
    }

    func rotateCurrentPage() {
        guard let document = document, let page = document.page(at: currentPageIndex) else { return }
        page.rotation = (page.rotation + 90) % 360
        // We need to trigger a UI update. Forcing a refresh of the document view might be needed.
        self.objectWillChange.send()
    }

    func deleteCurrentPage() {
        guard let document = document, document.pageCount > 1 else { return }
        deletePages(at: IndexSet(integer: currentPageIndex))
    }

    func deletePages(at indices: IndexSet) {
        guard let document = document, document.pageCount > 1 else { return }
        syncCurrentDrawing()
        let validIndices = IndexSet(indices.filter { $0 >= 0 && $0 < document.pageCount })
        guard !validIndices.isEmpty else { return }
        guard document.pageCount - validIndices.count >= 1 else { return }

        var newDrawings: [Int: PageDrawing] = [:]
        var newImages: [Int: [InsertedImage]] = [:]

        for oldIndex in 0..<document.pageCount where !validIndices.contains(oldIndex) {
            let deletedBefore = validIndices.filter { $0 < oldIndex }.count
            let newIndex = oldIndex - deletedBefore
            if let drawing = drawingsByPage[oldIndex] {
                newDrawings[newIndex] = drawing
            }
            if let images = imagesByPage[oldIndex] {
                newImages[newIndex] = images
            }
        }

        drawingsByPage = newDrawings
        imagesByPage = newImages

        for index in validIndices.sorted(by: >) {
            document.removePage(at: index)
        }

        if currentPageIndex >= document.pageCount {
            currentPageIndex = document.pageCount - 1
        } else {
            currentPageIndex -= validIndices.filter { $0 < currentPageIndex }.count
            currentPageIndex = min(max(currentPageIndex, 0), document.pageCount - 1)
        }

        drawingVersion += 1
        self.objectWillChange.send()
    }

    func movePage(from source: IndexSet, to destination: Int) {
        guard let document = document else { return }
        syncCurrentDrawing()

        let sourceIndices = Array(source)
        guard let firstSource = sourceIndices.first else { return }

        let pageToMove = document.page(at: firstSource)

        // Logical destination in the new array (after removal)
        let newDest = destination > firstSource ? destination - 1 : destination

        // Update drawings and images map
        var newDrawings: [Int: PageDrawing] = [:]
        var newImages: [Int: [InsertedImage]] = [:]
        let pageCount = document.pageCount
        var indices = Array(0..<pageCount)
        let movedIndex = indices.remove(at: firstSource)
        indices.insert(movedIndex, at: newDest)

        for (newIdx, oldIdx) in indices.enumerated() {
            if let drawing = drawingsByPage[oldIdx] {
                newDrawings[newIdx] = drawing
            }
            if let images = imagesByPage[oldIdx] {
                newImages[newIdx] = images
            }
        }
        drawingsByPage = newDrawings
        imagesByPage = newImages

        // Update PDF document
        document.removePage(at: firstSource)
        if let page = pageToMove {
            document.insert(page, at: newDest)
        }

        currentPageIndex = newDest
        drawingVersion += 1
        self.objectWillChange.send()
    }

    // MARK: - OCR

    func performOCR() {
        guard let document = document, let page = document.page(at: currentPageIndex) else { return }

        if !ProManager.shared.canPerformOCR() {
            showingPaywall = true
            return
        }

        isPerformingOCR = true
        extractedText = nil

        let pageSize = page.bounds(for: .mediaBox).size
        let image = page.thumbnail(of: CGSize(width: pageSize.width * 2, height: pageSize.height * 2), for: .mediaBox)

        Task {
            do {
                let text = try await OCRService.recognizeText(in: image)
                await MainActor.run {
                    self.extractedText = text
                    self.isPerformingOCR = false
                    ProManager.shared.incrementOCRUsage()
                }
            } catch {
                await MainActor.run {
                    self.isPerformingOCR = false
                }
            }
        }
    }

    // MARK: - Signatures

    func addSignatureToPage(_ signature: SavedSignature) {
        syncCurrentDrawing()

        guard let signatureImage = signature.renderedImage else { return }
        addImageToPage(signatureImage, label: "Signature", widthRatio: 0.42)
        isDrawingActive = false
    }

    // MARK: - Image Insertion

    func addImageToPage(_ image: UIImage) {
        addImageToPage(image, label: "Image", widthRatio: 0.4)
    }

    private func addImageToPage(_ image: UIImage, label: String, widthRatio: CGFloat) {
        guard let document = document, let page = document.page(at: currentPageIndex) else { return }
        guard image.size.width.isFinite, image.size.height.isFinite else { return }
        guard image.size.width > 1, image.size.height > 1 else { return }

        let pageSize = page.bounds(for: .mediaBox).size
        let imgWidth = image.size.width
        let imgHeight = image.size.height

        let targetWidth = pageSize.width * widthRatio
        let scale = targetWidth / imgWidth
        let targetHeight = imgHeight * scale

        let x = (pageSize.width - targetWidth) / 2
        let y = (pageSize.height - targetHeight) / 2

        if imagesByPage[currentPageIndex] == nil {
            imagesByPage[currentPageIndex] = []
        }
        imagesByPage[currentPageIndex]?.append(
            InsertedImage(
                image: image,
                bounds: CGRect(x: x, y: y, width: targetWidth, height: targetHeight),
                label: label
            )
        )

        drawingVersion += 1
        self.objectWillChange.send()
    }

    func updateImage(id: UUID, onPage pageIndex: Int, bounds: CGRect, notify: Bool = true) {
        guard var images = imagesByPage[pageIndex],
              let imageIndex = images.firstIndex(where: { $0.id == id }) else { return }

        images[imageIndex].bounds = bounds
        imagesByPage[pageIndex] = images
        if notify {
            drawingVersion += 1
        }
    }

    func deleteImage(id: UUID, onPage pageIndex: Int) {
        guard var images = imagesByPage[pageIndex] else { return }
        images.removeAll { $0.id == id }
        imagesByPage[pageIndex] = images
        drawingVersion += 1
        objectWillChange.send()
    }

    // MARK: - Shapes

    func addShapeToPage(_ shape: ShapeType) {
        guard let document = document, let page = document.page(at: currentPageIndex) else { return }

        let pageSize = page.bounds(for: .mediaBox).size
        let targetSize = CGSize(width: 100, height: 100)
        let rect = CGRect(
            x: (pageSize.width - targetSize.width) / 2,
            y: (pageSize.height - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )

        let annotationType: PDFAnnotationSubtype
        switch shape {
        case .rectangle: annotationType = .square
        case .circle: annotationType = .circle
        case .line, .arrow: annotationType = .line
        }

        let annotation = PDFAnnotation(bounds: rect, forType: annotationType, withProperties: nil)
        annotation.color = UIColor(selectedColor)
        annotation.userName = "SwiftPDFShape:\(UUID().uuidString)"
        let border = PDFBorder()
        border.lineWidth = 3
        annotation.border = border

        if shape == .line || shape == .arrow {
            annotation.startPoint = CGPoint(x: rect.minX, y: rect.maxY)
            annotation.endPoint = CGPoint(x: rect.maxX, y: rect.minY)
        }
        if shape == .arrow {
            annotation.endLineStyle = .closedArrow
        }

        page.addAnnotation(annotation)
        drawingVersion += 1
        self.objectWillChange.send()
    }

    func selectEditableObject(label: String) {
        selectedEditableObjectLabel = label
        hasSelectedEditableObject = true
    }

    func clearEditableObjectSelection() {
        hasSelectedEditableObject = false
        selectedEditableObjectLabel = ""
        onDeselectEditableObject?()
    }

    func deleteSelectedEditableObject() {
        onDeleteSelectedEditableObject?()
    }

    func applyTextStyleToSelectedObject() {
        onApplyTextStyleToSelectedObject?()
    }

    func selectTextAnnotation(_ annotation: PDFAnnotation, pageIndex: Int) {
        onSelectTextAnnotation?(annotation, pageIndex)
    }

    func extractPages(at indices: IndexSet) -> PDFDocument? {
        guard let document = document else { return nil }
        let newDoc = PDFDocument()

        for index in indices.sorted() {
            if let page = document.page(at: index) {
                if let pageCopy = page.copy() as? PDFPage {
                    newDoc.insert(pageCopy, at: newDoc.pageCount)
                }
            }
        }
        return newDoc.pageCount > 0 ? newDoc : nil
    }

    // MARK: - Smart Form Filling

    func smartAutofill() {
        guard let document = document else { return }
        let profile = profileStore.profile

        var foundAny = false
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations {
                guard let fieldName = annotation.fieldName?.lowercased() else { continue }

                if fieldName.contains("name") || fieldName.contains("first") || fieldName.contains("last") {
                    annotation.contents = profile.fullName
                    foundAny = true
                } else if fieldName.contains("email") {
                    annotation.contents = profile.email
                    foundAny = true
                } else if fieldName.contains("phone") || fieldName.contains("tel") {
                    annotation.contents = profile.phone
                    foundAny = true
                } else if fieldName.contains("address") {
                    annotation.contents = profile.address
                    foundAny = true
                } else if fieldName.contains("date") {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    annotation.contents = formatter.string(from: Date())
                    foundAny = true
                }
            }
        }

        if foundAny {
            drawingVersion += 1
            self.objectWillChange.send()
        }
    }

    // MARK: - Batch Actions

    func applyWatermarkToAllPages(text: String, color: Color, opacity: Double) {
        guard let document = document else { return }

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageSize = page.bounds(for: .mediaBox).size

            // Create a large centered watermark
            let font = UIFont.systemFont(ofSize: 60, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (text as NSString).size(withAttributes: attributes)

            let rect = CGRect(
                x: (pageSize.width - size.width) / 2,
                y: (pageSize.height - size.height) / 2,
                width: size.width,
                height: size.height
            )

            let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = font
            annotation.fontColor = UIColor(color).withAlphaComponent(CGFloat(opacity))
            annotation.color = .clear
            annotation.alignment = .center
            annotation.userName = "SwiftPDFWatermark"

            page.addAnnotation(annotation)
        }

        drawingVersion += 1
        self.objectWillChange.send()
    }
}
