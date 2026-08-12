//
//  PDFEditorView.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import PDFKit
import PencilKit
import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI
import Vision
import os

struct EditorView: View {
    @EnvironmentObject private var adService: AdMobService
    @ObservedObject var controller: PDFEditorController
    let onClose: () -> Void

    @State private var shareItem: ShareItem?
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var pendingTextTarget: TextTarget?
    @State private var textInput = ""
    @State private var showTextInput = false
    @State private var exportDocument: SignedPDFDocument?
    @State private var showFileExporter = false
    @State private var exportFileName = "Signed"
    @State private var savedURL: URL?
    @State private var showSavedAlert = false
    @State private var savedMessage = "Your signed PDF was saved."
    @State private var lastExportData: Data?
    @State private var lastExportBaseName = "Signed"
    @State private var exportCurrentPageOnly = false
    @State private var showSaveScopeOptions = false
    @State private var showSaveOptions = false
    @State private var pdfPassword = ""
    @State private var showingPasswordEntry = false
    @State private var showingPageSelector = false
    @State private var showsCanvasControls = true

    var body: some View {
        editorCanvas
            .navigationTitle(controller.fileName.isEmpty ? "PDF" : controller.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    editorMenu
                }
            }
            .editorSheetsAndDialogs(
                controller: controller,
                shareItem: $shareItem,
                showFileExporter: $showFileExporter,
                exportDocument: $exportDocument,
                exportFileName: exportFileName,
                showSavedAlert: $showSavedAlert,
                savedMessage: savedMessage,
                pendingTextTarget: $pendingTextTarget,
                textInput: $textInput,
                showTextInput: $showTextInput,
                showExportError: $showExportError,
                exportErrorMessage: exportErrorMessage,
                showingPageSelector: $showingPageSelector,
                showingPasswordEntry: $showingPasswordEntry,
                pdfPassword: $pdfPassword,
                showSaveScopeOptions: $showSaveScopeOptions,
                showSaveOptions: $showSaveOptions,
                exportCurrentPageOnly: $exportCurrentPageOnly,
                commitText: commitText,
                shareLastExport: shareLastExport,
                handleSuccessfulSave: handleSuccessfulSave,
                presentExportError: presentExportError,
                saveSignedPDF: saveSignedPDF
            )
            .alert(item: $controller.fontIdentificationResult) { result in
                if !result.matchFound {
                    return Alert(
                        title: Text("Font Not Found"),
                        message: Text("No readable text was found near that spot. Try tapping closer to the center of a word or use a clearer scan."),
                        dismissButton: .default(Text("OK"))
                    )
                }
                return Alert(
                    title: Text(result.isEmbeddedFont ? "Font Identified" : "Closest Font Match"),
                    message: Text(fontIdentificationMessage(result)),
                    primaryButton: .default(Text("Use This Font")) {
                        controller.applyFontIdentification(result)
                        controller.setTool(.correctText)
                    },
                    secondaryButton: .cancel()
                )
            }
    }

    private var editorCanvas: some View {
        let _ = controller.drawingVersion
        return ZStack {
            PDFEditorContainer(controller: controller) { target in
                pendingTextTarget = target
                textInput = target.initialText
                showTextInput = true
            }
                .ignoresSafeArea()

            if isUsingTextTool {
                Button(action: closeTextTool) {
                    Label("Close Text Tool", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(
                            Capsule()
                                .fill(Color.red)
                                .shadow(color: Color.black.opacity(0.2), radius: 9, x: 0, y: 5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Text Tool")
                .padding(.trailing, 20)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }

            if showsCanvasControls {
                VStack(spacing: 12) {
                Spacer()

                if controller.activeTool == .correctText {
                    Label("Tap the text or date you want to replace", systemImage: "text.cursor")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                }

                if controller.activeTool == .identifyFont {
                    Label(
                        controller.isIdentifyingFont ? "Comparing fonts on your device" : "Tap the text whose font you want to identify",
                        systemImage: controller.isIdentifyingFont ? "hourglass" : "text.magnifyingglass"
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .padding(.bottom, 86)
                }

                if controller.activeTool == .text || controller.activeTool == .correctText {
                    HStack {
                        TextToolPalette(controller: controller)
                        Spacer(minLength: 160)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 86)
                }

                if controller.hasSelectedEditableObject {
                    Button(role: .destructive) {
                        controller.deleteSelectedEditableObject()
                    } label: {
                        Label("Delete \(controller.selectedEditableObjectLabel)", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .background(Capsule().fill(Color(.systemBackground)))
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                }

                PageNavigationControl(controller: controller) {
                    showingPageSelector = true
                }
                .padding(.bottom, 22)
                }
                .padding(.horizontal, 18)
            }

            if showsCanvasControls {
                VStack(alignment: .trailing, spacing: 10) {
                if controller.isDrawingActive {
                    HStack(alignment: .bottom, spacing: 10) {
                        DrawingToolPalette(controller: controller)
                        EditorActionButton(
                            title: "Finish Drawing",
                            systemImage: "checkmark",
                            color: .accentColor,
                            action: toggleDrawing
                        )
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    EditorActionButton(title: "Signature", systemImage: "signature", color: .orange) {
                        controller.showingSignatureLibrary = true
                    }
                    EditorActionButton(title: "Shapes", systemImage: "square.on.circle", color: .purple) {
                        controller.showingShapePicker = true
                    }
                    EditorActionButton(title: "Save PDF", systemImage: "tray.and.arrow.down", color: .black) {
                        beginSaveFlow()
                    }
                    EditorActionButton(title: "Share PDF", systemImage: "square.and.arrow.up", color: .green) {
                        shareSignedPDF()
                    }
                    EditorActionButton(title: "Draw", systemImage: "pencil.and.outline", color: .accentColor) {
                        toggleDrawing()
                    }
                }
                }
                .animation(.spring(duration: 0.3), value: controller.isDrawingActive)
                .animation(.spring(duration: 0.3), value: controller.activeTool)
                .padding(.trailing, 24)
                .padding(.bottom, 92)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private var editorMenu: some View {
        Menu {
            Button {
                withAnimation { showsCanvasControls.toggle() }
            } label: {
                Label(
                    showsCanvasControls ? "Hide Canvas Controls" : "Show Canvas Controls",
                    systemImage: showsCanvasControls ? "eye.slash" : "eye"
                )
            }

            Button(action: toggleDrawing) {
                Label(
                    controller.isDrawingActive ? "Finish Drawing" : "Start Drawing",
                    systemImage: controller.isDrawingActive ? "checkmark" : "pencil.and.outline"
                )
            }

            Menu {
                Button(action: controller.zoomIn) {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
                Button(action: controller.zoomOut) {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                Button(action: controller.fitPage) {
                    Label("Fit Page", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } label: {
                Label("Zoom", systemImage: "magnifyingglass")
            }

            Menu {
                textToolButtons
            } label: {
                Label("Text Tools", systemImage: "textformat")
            }

            Divider()

            Button(action: undoStroke) {
                Label("Undo Drawing Stroke", systemImage: "arrow.uturn.backward")
            }
            .disabled(!controller.canUndoCurrentPage())

            if controller.hasSelectedEditableObject {
                Button(role: .destructive, action: controller.deleteSelectedEditableObject) {
                    Label("Delete \(controller.selectedEditableObjectLabel)", systemImage: "trash")
                }
            }

            Divider()

            Button("Rotate Page") { controller.rotateCurrentPage() }
            Button("Manage Pages") { controller.showingPageManager = true }
            Button("Add Image") { controller.showingImagePicker = true }
            Button(pdfPassword.isEmpty ? "Protect with Password" : "Change Password") {
                if ProManager.shared.isPro {
                    showingPasswordEntry = true
                } else {
                    controller.showingPaywall = true
                }
            }
            Button("Batch Watermark") {
                if ProManager.shared.isPro {
                    controller.showingWatermarkEditor = true
                } else {
                    controller.showingPaywall = true
                }
            }
            Button("Autofill Form") {
                if ProManager.shared.isPro {
                    controller.smartAutofill()
                } else {
                    controller.showingPaywall = true
                }
            }
            Button("Edit Autofill Profile") { controller.showingProfileEditor = true }
            Button("Extract Text with OCR") { controller.performOCR() }
                .disabled(controller.isPerformingOCR)
            if controller.hasDrawingOnCurrentPage() {
                Button("Clear Drawing", role: .destructive, action: clearDrawing)
            }
            Button("Delete Page", role: .destructive) { controller.deleteCurrentPage() }

            Divider()

            Button(action: shareSignedPDF) {
                Label("Share PDF", systemImage: "square.and.arrow.up")
            }
        } label: {
            Label("Editor Menu", systemImage: "ellipsis.circle")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Editor Menu")
    }

    private var isUsingTextTool: Bool {
        controller.activeTool == .text || controller.activeTool == .correctText || controller.activeTool == .identifyFont
    }

    private func closeTextTool() {
        pendingTextTarget = nil
        showTextInput = false
        controller.isIdentifyingFont = false
        controller.fontIdentificationResult = nil
        controller.setTool(.draw)
    }

    @ViewBuilder
    private var textToolButtons: some View {
            Button {
                controller.setTool(.text)
            } label: {
                Label("Add Text", systemImage: "textformat")
            }

            Button {
                if ProManager.shared.isPro {
                    controller.setTool(.correctText)
                } else {
                    controller.showingPaywall = true
                }
            } label: {
                Label(
                    "Correct Text or Date",
                    systemImage: ProManager.shared.isPro ? "text.badge.checkmark" : "lock.fill"
                )
            }


            Button {
                if ProManager.shared.isPro {
                    controller.setTool(.identifyFont)
                } else {
                    controller.showingPaywall = true
                }
            } label: {
                Label(
                    "Identify Font",
                    systemImage: ProManager.shared.isPro ? "text.magnifyingglass" : "lock.fill"
                )
            }

            if controller.activeTool == .text || controller.activeTool == .correctText || controller.activeTool == .identifyFont {
                Button("Done Editing Text") {
                    controller.setTool(.draw)
                }
            }
    }

    private func toggleDrawing() {
        controller.toggleDrawing()
    }

    private func shareSignedPDF() {
        guard let document = controller.document else { return }
        controller.syncCurrentDrawing()
        let drawings = controller.allDrawings()
        let images = controller.allImages()
        let data = PDFExporter.flatten(document: document, drawings: drawings, images: images, password: pdfPassword, quality: controller.exportCompressionQuality) ?? document.dataRepresentation()
        guard let data else {
            presentExportError("The PDF could not be prepared for sharing.")
            return
        }

        let title = makeExportFileName()
        if let tempURL = writeTemporaryExport(data: data, baseName: title) {
            shareItem = ShareItem(items: [tempURL])
        } else {
            presentExportError("The PDF could not be prepared for sharing.")
        }
    }

    private func beginSaveFlow() {
        showSaveScopeOptions = true
    }

    private func saveSignedPDF(overwriteOriginal: Bool) {
        guard let data = makeExportData(currentPageOnly: exportCurrentPageOnly) else {
            presentExportError("The PDF could not be saved.")
            return
        }

        lastExportData = data
        lastExportBaseName = makeExportFileName(currentPageOnly: exportCurrentPageOnly)

        if overwriteOriginal, saveToOriginalLocationIfPossible(data) {
            return
        }

        exportFileName = lastExportBaseName
        exportDocument = SignedPDFDocument(data: data)
        showFileExporter = true
    }

    private func makeExportData(currentPageOnly: Bool) -> Data? {
        guard let document = controller.document else { return nil }
        controller.syncCurrentDrawing()

        if currentPageOnly {
            let currentIndex = controller.currentPageIndex
            guard let currentDocument = controller.extractPages(at: IndexSet(integer: currentIndex)) else {
                return nil
            }
            var drawings: [Int: PageDrawing] = [:]
            var images: [Int: [PDFEditorController.InsertedImage]] = [:]
            if let drawing = controller.drawing(forPage: currentIndex) {
                drawings[0] = drawing
            }
            let currentImages = controller.images(forPage: currentIndex)
            if !currentImages.isEmpty {
                images[0] = currentImages
            }
            return PDFExporter.flatten(
                document: currentDocument,
                drawings: drawings,
                images: images,
                password: pdfPassword,
                quality: controller.exportCompressionQuality
            ) ?? currentDocument.dataRepresentation()
        }

        let data = PDFExporter.flatten(
            document: document,
            drawings: controller.allDrawings(),
            images: controller.allImages(),
            password: pdfPassword,
            quality: controller.exportCompressionQuality
        ) ?? document.dataRepresentation()
        guard let data else {
            return nil
        }
        return data
    }

    private func makeExportFileName(currentPageOnly: Bool = false) -> String {
        let baseName: String
        if controller.fileName.isEmpty {
            baseName = "Signed"
        } else {
            baseName = (controller.fileName as NSString).deletingPathExtension
        }
        let safeBase = baseName.isEmpty ? "Signed" : baseName
        if currentPageOnly {
            return "\(safeBase)-Page-\(controller.currentPageIndex + 1)-Signed"
        }
        return "\(safeBase)-Signed"
    }

    private func saveToOriginalLocationIfPossible(_ data: Data) -> Bool {
        guard let sourceURL = controller.sourceURL else { return false }
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            try data.write(to: sourceURL, options: [.atomic])
            handleSuccessfulSave(url: sourceURL, message: "Saved to the original file.")
            return true
        } catch {
            return false
        }
    }

    private func handleSuccessfulSave(url: URL, message: String) {
        adService.maybePresentSaveAd {
            savedURL = url
            savedMessage = message
            showSavedAlert = true
        }
    }

    private func presentExportError(_ message: String) {
        exportErrorMessage = message
        showExportError = true
    }

    private func shareLastExport() {
        if let data = lastExportData,
           let tempURL = writeTemporaryExport(data: data, baseName: lastExportBaseName) {
            shareItem = ShareItem(items: [tempURL])
            return
        }
        if let savedURL {
            shareItem = ShareItem(items: [savedURL])
        }
    }

    private func writeTemporaryExport(data: Data, baseName: String) -> URL? {
        let name = baseName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString.prefix(6)).pdf")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    private func undoStroke() {
        controller.undoLastStroke()
    }

    private func clearDrawing() {
        controller.clearCurrentDrawing()
    }

    private func fontIdentificationMessage(_ result: FontIdentificationResult) -> String {
        let style = [result.bold ? "Bold" : nil, result.italic ? "Italic" : nil]
            .compactMap { $0 }
            .joined(separator: " ")
        let styleText = style.isEmpty ? "Regular" : style
        if result.isEmbeddedFont {
            return "The PDF reports \(result.detectedName). The closest editable choice is \(result.closestFamily.rawValue), \(styleText), at about \(Int(result.size.rounded())) points."
        }
        return "On device visual matching found \(result.closestFamily.rawValue), \(styleText), at about \(Int(result.size.rounded())) points. Scanned text matching is an estimate because the original font data is not stored in the PDF."
    }

    private func commitText() {
        guard let target = pendingTextTarget else { return }
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let annotation = PDFTextAnnotator.addOrUpdateText(trimmed, target: target, document: controller.document, controller: controller) {
            controller.selectTextAnnotation(annotation, pageIndex: target.pageIndex)
            controller.drawingVersion += 1
            controller.objectWillChange.send()
        }
        pendingTextTarget = nil
        textInput = ""
    }
}

private extension View {
    func editorSheetsAndDialogs(
        controller: PDFEditorController,
        shareItem: Binding<ShareItem?>,
        showFileExporter: Binding<Bool>,
        exportDocument: Binding<SignedPDFDocument?>,
        exportFileName: String,
        showSavedAlert: Binding<Bool>,
        savedMessage: String,
        pendingTextTarget: Binding<TextTarget?>,
        textInput: Binding<String>,
        showTextInput: Binding<Bool>,
        showExportError: Binding<Bool>,
        exportErrorMessage: String,
        showingPageSelector: Binding<Bool>,
        showingPasswordEntry: Binding<Bool>,
        pdfPassword: Binding<String>,
        showSaveScopeOptions: Binding<Bool>,
        showSaveOptions: Binding<Bool>,
        exportCurrentPageOnly: Binding<Bool>,
        commitText: @escaping () -> Void,
        shareLastExport: @escaping () -> Void,
        handleSuccessfulSave: @escaping (URL, String) -> Void,
        presentExportError: @escaping (String) -> Void,
        saveSignedPDF: @escaping (Bool) -> Void
    ) -> some View {
        modifier(EditorSheetsAndDialogsModifier(
            controller: controller,
            shareItem: shareItem,
            showFileExporter: showFileExporter,
            exportDocument: exportDocument,
            exportFileName: exportFileName,
            showSavedAlert: showSavedAlert,
            savedMessage: savedMessage,
            pendingTextTarget: pendingTextTarget,
            textInput: textInput,
            showTextInput: showTextInput,
            showExportError: showExportError,
            exportErrorMessage: exportErrorMessage,
            showingPageSelector: showingPageSelector,
            showingPasswordEntry: showingPasswordEntry,
            pdfPassword: pdfPassword,
            showSaveScopeOptions: showSaveScopeOptions,
            showSaveOptions: showSaveOptions,
            exportCurrentPageOnly: exportCurrentPageOnly,
            commitText: commitText,
            shareLastExport: shareLastExport,
            handleSuccessfulSave: handleSuccessfulSave,
            presentExportError: presentExportError,
            saveSignedPDF: saveSignedPDF
        ))
    }
}

private struct EditorSheetsAndDialogsModifier: ViewModifier {
    @ObservedObject var controller: PDFEditorController
    @Binding var shareItem: ShareItem?
    @Binding var showFileExporter: Bool
    @Binding var exportDocument: SignedPDFDocument?
    let exportFileName: String
    @Binding var showSavedAlert: Bool
    let savedMessage: String
    @Binding var pendingTextTarget: TextTarget?
    @Binding var textInput: String
    @Binding var showTextInput: Bool
    @Binding var showExportError: Bool
    let exportErrorMessage: String
    @Binding var showingPageSelector: Bool
    @Binding var showingPasswordEntry: Bool
    @Binding var pdfPassword: String
    @Binding var showSaveScopeOptions: Bool
    @Binding var showSaveOptions: Bool
    @Binding var exportCurrentPageOnly: Bool
    let commitText: () -> Void
    let shareLastExport: () -> Void
    let handleSuccessfulSave: (URL, String) -> Void
    let presentExportError: (String) -> Void
    let saveSignedPDF: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .shareSheet($shareItem)
            .editorFileExporter(
                isPresented: $showFileExporter,
                document: $exportDocument,
                fileName: exportFileName,
                handleSuccessfulSave: handleSuccessfulSave,
                presentExportError: presentExportError
            )
            .editorAlerts(
                showSavedAlert: $showSavedAlert,
                savedMessage: savedMessage,
                pendingTextTarget: $pendingTextTarget,
                textInput: $textInput,
                showTextInput: $showTextInput,
                showExportError: $showExportError,
                exportErrorMessage: exportErrorMessage,
                commitText: commitText,
                shareLastExport: shareLastExport
            )
            .editorSheets(
                controller: controller,
                showingPageSelector: $showingPageSelector,
                showingPasswordEntry: $showingPasswordEntry,
                pdfPassword: $pdfPassword
            )
            .editorActionDialogs(
                controller: controller,
                showSaveScopeOptions: $showSaveScopeOptions,
                showSaveOptions: $showSaveOptions,
                exportCurrentPageOnly: $exportCurrentPageOnly,
                saveSignedPDF: saveSignedPDF
            )
    }
}

private extension View {
    func shareSheet(_ shareItem: Binding<ShareItem?>) -> some View {
        sheet(item: shareItem) { item in
            ShareSheet(items: item.items) {
                shareItem.wrappedValue = nil
            }
        }
    }

    func editorFileExporter(
        isPresented: Binding<Bool>,
        document: Binding<SignedPDFDocument?>,
        fileName: String,
        handleSuccessfulSave: @escaping (URL, String) -> Void,
        presentExportError: @escaping (String) -> Void
    ) -> some View {
        fileExporter(
            isPresented: isPresented,
            document: document.wrappedValue,
            contentType: .pdf,
            defaultFilename: fileName
        ) { result in
            defer { document.wrappedValue = nil }
            switch result {
            case .success(let url):
                handleSuccessfulSave(url, "Saved to Files.")
            case .failure:
                presentExportError("The PDF could not be saved to Files.")
            }
        }
    }

    func editorAlerts(
        showSavedAlert: Binding<Bool>,
        savedMessage: String,
        pendingTextTarget: Binding<TextTarget?>,
        textInput: Binding<String>,
        showTextInput: Binding<Bool>,
        showExportError: Binding<Bool>,
        exportErrorMessage: String,
        commitText: @escaping () -> Void,
        shareLastExport: @escaping () -> Void
    ) -> some View {
        self
            .alert("Saved", isPresented: showSavedAlert) {
                Button("Share", action: shareLastExport)
                Button("Done", role: .cancel) {}
            } message: {
                Text(savedMessage)
            }
            .alert(textDialogTitle(for: pendingTextTarget.wrappedValue), isPresented: showTextInput) {
                TextField("Text", text: textInput)
                Button(textDialogButtonTitle(for: pendingTextTarget.wrappedValue), action: commitText)
                Button("Cancel", role: .cancel) {
                    pendingTextTarget.wrappedValue = nil
                }
            } message: {
                Text(textDialogMessage(for: pendingTextTarget.wrappedValue))
            }
            .alert("Could not export PDF", isPresented: showExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
    }

    private func textDialogTitle(for target: TextTarget?) -> String {
        if target?.mode == .correction { return "Correct Text or Date" }
        return target?.annotation == nil ? "Add Text" : "Edit Text"
    }

    private func textDialogButtonTitle(for target: TextTarget?) -> String {
        if target?.mode == .correction { return "Replace" }
        return target?.annotation == nil ? "Add" : "Save"
    }

    private func textDialogMessage(for target: TextTarget?) -> String {
        if target?.mode == .correction {
            return "Enter the corrected text or date. The original area will be covered. You can drag or pinch the correction after adding it."
        }
        return "Enter text for the spot you tapped. After adding it, drag to move or pinch to resize."
    }

    func editorSheets(
        controller: PDFEditorController,
        showingPageSelector: Binding<Bool>,
        showingPasswordEntry: Binding<Bool>,
        pdfPassword: Binding<String>
    ) -> some View {
        self
            .sheet(isPresented: Binding(
                get: { controller.extractedText != nil },
                set: { if !$0 { controller.extractedText = nil } }
            )) {
                if let text = controller.extractedText {
                    OCRResultView(text: text)
                }
            }
            .sheet(isPresented: showingPageSelector) {
                PageSelectorView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingSignatureLibrary },
                set: { controller.showingSignatureLibrary = $0 }
            )) {
                SignatureLibraryView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingSignaturePad },
                set: { controller.showingSignaturePad = $0 }
            )) {
                SignaturePadView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingPageManager },
                set: { controller.showingPageManager = $0 }
            )) {
                PageManagerView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingImagePicker },
                set: { controller.showingImagePicker = $0 }
            )) {
                ImagePickerView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingShapePicker },
                set: { controller.showingShapePicker = $0 }
            )) {
                ShapePickerView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingWatermarkEditor },
                set: { controller.showingWatermarkEditor = $0 }
            )) {
                WatermarkEditorView(controller: controller)
            }
            .sheet(isPresented: Binding(
                get: { controller.showingProfileEditor },
                set: { controller.showingProfileEditor = $0 }
            )) {
                ProfileEditorView()
            }
            .sheet(isPresented: Binding(
                get: { controller.showingPaywall },
                set: { controller.showingPaywall = $0 }
            )) {
                PaywallView()
            }
            .sheet(isPresented: showingPasswordEntry) {
                PasswordEntryView(password: pdfPassword)
            }
    }

    func editorActionDialogs(
        controller: PDFEditorController,
        showSaveScopeOptions: Binding<Bool>,
        showSaveOptions: Binding<Bool>,
        exportCurrentPageOnly: Binding<Bool>,
        saveSignedPDF: @escaping (Bool) -> Void
    ) -> some View {
        self
            .confirmationDialog("Save Pages", isPresented: showSaveScopeOptions, titleVisibility: .visible) {
                Button("All Pages") {
                    exportCurrentPageOnly.wrappedValue = false
                    showSaveOptions.wrappedValue = true
                }
                Button("Current Page Only") {
                    exportCurrentPageOnly.wrappedValue = true
                    showSaveOptions.wrappedValue = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose which pages to include in the saved PDF.")
            }
            .confirmationDialog("Save PDF", isPresented: showSaveOptions, titleVisibility: .visible) {
                saveActionButtons(
                    controller: controller,
                    exportCurrentPageOnly: exportCurrentPageOnly.wrappedValue,
                    saveSignedPDF: saveSignedPDF
                )
            }
    }

    @ViewBuilder
    private func saveActionButtons(
        controller: PDFEditorController,
        exportCurrentPageOnly: Bool,
        saveSignedPDF: @escaping (Bool) -> Void
    ) -> some View {
        if ProManager.shared.isPro {
            Menu("Compression") {
                Button("Low (High Quality)") {
                    controller.exportCompressionQuality = 1.0
                }
                Button("Medium") {
                    controller.exportCompressionQuality = 0.5
                }
                Button("Small (Low Quality)") {
                    controller.exportCompressionQuality = 0.2
                }
            }
        }
        if controller.sourceURL != nil {
            Button(exportCurrentPageOnly ? "Overwrite with Current Page" : "Overwrite Current File") {
                saveSignedPDF(true)
            }
        }
        Button(exportCurrentPageOnly ? "Save Current Page as New File" : "Save as New File") {
            saveSignedPDF(false)
        }
        Button("Cancel", role: .cancel) {}
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

enum TextEditMode {
    case addition
    case correction
}

struct TextTarget {
    let pageIndex: Int
    let point: CGPoint
    let annotation: PDFAnnotation?
    let mode: TextEditMode
    let sourceBounds: CGRect?
    let sourceText: String?

    var initialText: String {
        annotation?.contents ?? sourceText ?? ""
    }
}

private struct EditorActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(minWidth: 112, minHeight: 44, alignment: .leading)
                .background(
                    Capsule()
                        .fill(color)
                        .shadow(color: Color.black.opacity(0.2), radius: 9, x: 0, y: 5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct PageNavigationControl: View {
    @ObservedObject var controller: PDFEditorController
    let showSelector: () -> Void

    var body: some View {
        let pageCount = controller.document?.pageCount ?? 0

        HStack(spacing: 10) {
            Button(action: controller.goToPreviousPage) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .disabled(controller.currentPageIndex <= 0)

            Button(action: showSelector) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                    Text("Page \(controller.currentPageIndex + 1) of \(max(pageCount, 1))")
                        .font(.headline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
            }
            .disabled(pageCount <= 0)

            Button(action: controller.goToNextPage) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .disabled(controller.currentPageIndex >= pageCount - 1)
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}

struct PageSelectorView: View {
    @ObservedObject var controller: PDFEditorController
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        if let document = controller.document {
                            ForEach(0..<document.pageCount, id: \.self) { index in
                                if let page = document.page(at: index) {
                                    Button {
                                        controller.goToPage(index)
                                        dismiss()
                                    } label: {
                                        PageThumbnailCell(
                                            page: page,
                                            index: index,
                                            isSelected: controller.currentPageIndex == index
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    proxy.scrollTo(controller.currentPageIndex, anchor: .center)
                }
            }
            .navigationTitle("Choose Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage") {
                        dismiss()
                        controller.showingPageManager = true
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct DrawingToolPalette: View {
    @ObservedObject var controller: PDFEditorController
    private let colors: [Color] = [.black, .red, .blue, .green, .orange]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(DrawingToolType.allCases, id: \.self) { tool in
                Button(action: { controller.setDrawingTool(tool) }) {
                    Image(systemName: tool.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(controller.drawingTool == tool ? Color.white : .primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(controller.drawingTool == tool ? Color.accentColor : Color(.secondarySystemBackground))
                        )
                }
            }

            Divider()
                .frame(width: 20)

            ForEach(colors, id: \.self) { color in
                Button(action: { controller.setColor(color) }) {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: controller.selectedColor == color ? 2 : 0)
                        )
                        .shadow(radius: 1)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5)
        )
    }
}

struct TextToolPalette: View {
    @ObservedObject var controller: PDFEditorController
    @State private var dragOffset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero
    private let colors: [Color] = [.black, .red, .blue, .gray]
    private let sizes: [CGFloat] = [12, 16, 24, 32, 48]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(controller.hasSelectedEditableObject ? "Text Style" : "Tap text to style")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        settledOffset.width += value.translation.width
                        settledOffset.height += value.translation.height
                        dragOffset = .zero
                    }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(TextFontFamily.allCases, id: \.self) { family in
                            Button {
                                controller.textFontFamily = family
                                controller.applyTextStyleToSelectedObject()
                            } label: {
                                if controller.textFontFamily == family {
                                    Label(family.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(family.rawValue)
                                }
                            }
                        }
                    } label: {
                        Label(controller.textFontFamily.rawValue, systemImage: "textformat")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }

                    FormatToggleButton(title: "B", isActive: controller.textBold) {
                        controller.textBold.toggle()
                        controller.applyTextStyleToSelectedObject()
                    }
                    FormatToggleButton(title: "I", isActive: controller.textItalic) {
                        controller.textItalic.toggle()
                        controller.applyTextStyleToSelectedObject()
                    }
                    FormatToggleButton(title: "S", isActive: controller.textStrikethrough, strikethrough: true) {
                        controller.textStrikethrough.toggle()
                        controller.applyTextStyleToSelectedObject()
                    }

                    Divider()
                        .frame(height: 24)

                    ForEach(sizes, id: \.self) { size in
                        Button {
                            controller.textSize = size
                            controller.applyTextStyleToSelectedObject()
                        } label: {
                            Text("\(Int(size))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(controller.textSize == size ? Color.white : .primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(controller.textSize == size ? Color.accentColor : Color(.secondarySystemBackground))
                                )
                        }
                    }

                    Divider()
                        .frame(height: 24)

                    ForEach(colors, id: \.self) { color in
                        Button {
                            controller.textColor = color
                            controller.applyTextStyleToSelectedObject()
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: controller.textColor == color ? 2 : 0)
                                )
                                .shadow(radius: 1)
                        }
                    }

                    if controller.activeTool == .correctText || controller.selectedEditableObjectLabel == "Correction" {
                        Divider()
                            .frame(height: 24)

                        HStack(spacing: 6) {
                            Text("Background")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ColorPicker(
                                "Correction Background",
                                selection: $controller.correctionBackgroundColor,
                                supportsOpacity: false
                            )
                            .labelsHidden()
                            .onChange(of: controller.correctionBackgroundColor) {
                                controller.applyTextStyleToSelectedObject()
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 8)
        )
        .frame(maxWidth: 340)
        .offset(
            x: settledOffset.width + dragOffset.width,
            y: settledOffset.height + dragOffset.height
        )
    }
}

private struct FormatToggleButton: View {
    let title: String
    let isActive: Bool
    var strikethrough = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .italic(title == "I")
                .strikethrough(strikethrough)
                .foregroundStyle(isActive ? Color.white : .primary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isActive ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
    }
}

struct OCRResultView: View {
    let text: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .navigationTitle("Extracted Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SignatureLibraryView: View {
    @ObservedObject var controller: PDFEditorController
    @ObservedObject private var signatureStore: SignatureStore
    @ObservedObject private var proManager = ProManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingSignaturePad = false
    @State private var showingPaywall = false

    init(controller: PDFEditorController) {
        self.controller = controller
        self.signatureStore = controller.signatureStore
    }

    var body: some View {
        NavigationStack {
            Group {
                if signatureStore.signatures.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "signature")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No saved signatures yet.")
                            .font(.headline)
                        Button("Create Signature") {
                            requestNewSignature()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(signatureStore.signatures) { signature in
                            Button {
                                controller.addSignatureToPage(signature)
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    if let image = signature.renderedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 72)
                                            .frame(maxWidth: .infinity)
                                    }

                                    if let style = signature.fontStyle {
                                        Text(style.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete { offsets in
                            signatureStore.remove(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Your Signatures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requestNewSignature()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSignaturePad) {
                SignaturePadView(controller: controller)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private func requestNewSignature() {
        if proManager.isPro || signatureStore.signatures.isEmpty {
            showingSignaturePad = true
        } else {
            showingPaywall = true
        }
    }
}

private enum SignatureCreationMode: String, CaseIterable, Identifiable {
    case draw = "Draw"
    case type = "Type"

    var id: Self { self }
}

struct SignaturePadView: View {
    @ObservedObject var controller: PDFEditorController
    @State private var drawing = PKDrawing()
    @State private var mode: SignatureCreationMode = .draw
    @State private var typedName = ""
    @State private var selectedFontStyle: SignatureFontStyle = .classic
    @FocusState private var nameFieldFocused: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Signature method", selection: $mode) {
                    ForEach(SignatureCreationMode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)

                if mode == .draw {
                    Text("Sign below")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PKCanvasViewWrapper(drawing: $drawing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                } else {
                    typedSignatureEditor
                }

                HStack(spacing: 40) {
                    Button("Clear") {
                        clearCurrentSignature()
                    }
                    .foregroundStyle(.red)

                    Button("Save Signature") {
                        if mode == .draw, !drawing.strokes.isEmpty {
                            controller.signatureStore.add(drawing: drawing)
                            dismiss()
                        } else if mode == .type {
                            controller.signatureStore.addTyped(
                                name: typedName,
                                style: selectedFontStyle
                            )
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveSignature)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("New Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var typedSignatureEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Signer name", text: $typedName)
                    .font(.title3)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFieldFocused)
                    .padding(14)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )

                VStack(spacing: 8) {
                    Text(typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your Name" : typedName)
                        .font(selectedFontStyle.swiftUIFont(size: selectedFontStyle == .flourish ? 34 : 46))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: .infinity, minHeight: 110)

                    Text(selectedFontStyle.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                Text("Choose a Signature Style")
                    .font(.headline)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(SignatureFontStyle.allCases) { style in
                        Button {
                            selectedFontStyle = style
                        } label: {
                            VStack(spacing: 6) {
                                Text(typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your Name" : typedName)
                                    .font(style.swiftUIFont(size: style == .flourish ? 18 : 25))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.45)
                                    .frame(maxWidth: .infinity, minHeight: 42)

                                Text(style.rawValue)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                            .padding(12)
                            .background(
                                selectedFontStyle == style
                                    ? Color.accentColor.opacity(0.16)
                                    : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedFontStyle == style ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(style.rawValue) signature style")
                        .accessibilityAddTraits(selectedFontStyle == style ? .isSelected : [])
                    }
                }

                Text("Each saved typed signature keeps its selected name and style. Choose a different style for each signer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .onAppear { nameFieldFocused = true }
    }

    private var canSaveSignature: Bool {
        switch mode {
        case .draw:
            !drawing.strokes.isEmpty
        case .type:
            !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func clearCurrentSignature() {
        switch mode {
        case .draw:
            drawing = PKDrawing()
        case .type:
            typedName = ""
            nameFieldFocused = true
        }
    }
}

struct PageManagerView: View {
    @ObservedObject var controller: PDFEditorController
    @Environment(\.dismiss) var dismiss
    @State private var isSelectionMode = false
    @State private var selectedIndices = IndexSet()
    @State private var exportExtractedDoc: SignedPDFDocument?
    @State private var showFileExporter = false
    @State private var showExportError = false
    @State private var showBulkDeleteConfirmation = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    if let document = controller.document {
                        ForEach(0..<document.pageCount, id: \.self) { index in
                            if let page = document.page(at: index) {
                                ZStack(alignment: .topTrailing) {
                                    PageThumbnailCell(page: page, index: index, isSelected: isSelectionMode ? selectedIndices.contains(index) : controller.currentPageIndex == index)
                                        .onTapGesture {
                                            if isSelectionMode {
                                                if selectedIndices.contains(index) {
                                                    selectedIndices.remove(index)
                                                } else {
                                                    selectedIndices.insert(index)
                                                }
                                            } else {
                                                controller.goToPage(index)
                                                dismiss()
                                            }
                                        }

                                    if isSelectionMode {
                                        Image(systemName: selectedIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedIndices.contains(index) ? Color.accentColor : .secondary)
                                            .padding(8)
                                    } else {
                                        PageManagementControls(
                                            canMoveUp: index > 0,
                                            canMoveDown: index < document.pageCount - 1,
                                            canDelete: document.pageCount > 1,
                                            moveUp: {
                                                controller.movePage(from: IndexSet(integer: index), to: index - 1)
                                            },
                                            moveDown: {
                                                controller.movePage(from: IndexSet(integer: index), to: index + 2)
                                            },
                                            delete: {
                                                controller.deletePages(at: IndexSet(integer: index))
                                            }
                                        )
                                        .padding(6)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Manage Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSelectionMode ? "Cancel" : "Done") {
                        if isSelectionMode {
                            isSelectionMode = false
                            selectedIndices.removeAll()
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSelectionMode {
                        Button("Delete", role: .destructive) {
                            showBulkDeleteConfirmation = true
                        }
                        .disabled(selectedIndices.isEmpty || selectedIndices.count >= (controller.document?.pageCount ?? 0))

                        Button("Extract") {
                            extractSelectedPages()
                        }
                        .disabled(selectedIndices.isEmpty)
                    } else {
                        Button(isSelectionMode ? "" : "Select") {
                            isSelectionMode.toggle()
                        }
                    }
                }
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: exportExtractedDoc,
                contentType: .pdf,
                defaultFilename: "Extracted"
            ) { result in
                exportExtractedDoc = nil
                if case .failure = result {
                    showExportError = true
                }
            }
            .alert("Export Failed", isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The extracted pages could not be saved. Please try again.")
            }
            .confirmationDialog("Delete Selected Pages?", isPresented: $showBulkDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete \(selectedIndices.count) Pages", role: .destructive) {
                    controller.deletePages(at: selectedIndices)
                    selectedIndices.removeAll()
                    isSelectionMode = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func extractSelectedPages() {
        guard let newDoc = controller.extractPages(at: selectedIndices) else { return }
        if let data = newDoc.dataRepresentation() {
            exportExtractedDoc = SignedPDFDocument(data: data)
            showFileExporter = true
        }
    }
}

private struct PageManagementControls: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canDelete: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMoveUp)

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMoveDown)

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .disabled(!canDelete)
        }
        .font(.caption.weight(.bold))
        .buttonStyle(.plain)
        .padding(8)
        .background(.regularMaterial, in: Capsule())
    }
}

struct PageThumbnailCell: View {
    let page: PDFPage
    let index: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(uiImage: page.thumbnail(of: CGSize(width: 150, height: 200), for: .mediaBox))
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            Text("Page \(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ImagePickerView: View {
    @ObservedObject var controller: PDFEditorController
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Select Photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding()
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                controller.addImageToPage(image)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ShapePickerView: View {
    @ObservedObject var controller: PDFEditorController
    @Environment(\.dismiss) var dismiss

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(ShapeType.allCases, id: \.self) { shape in
                        Button {
                            controller.addShapeToPage(shape)
                            dismiss()
                        } label: {
                            VStack {
                                ShapeIconView(shape: shape)
                                    .frame(width: 68, height: 80)

                                Text(shape.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Add Shape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ShapeIconView: View {
    let shape: ShapeType

    var body: some View {
        Group {
            switch shape {
            case .rectangle, .circle:
                Image(systemName: shape.rawValue)
                    .font(.system(size: 40, weight: .regular))
            case .line:
                Path { path in
                    path.move(to: CGPoint(x: 12, y: 58))
                    path.addLine(to: CGPoint(x: 56, y: 22))
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            case .arrow:
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 12, y: 58))
                        path.addLine(to: CGPoint(x: 56, y: 22))
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    Path { path in
                        path.move(to: CGPoint(x: 56, y: 22))
                        path.addLine(to: CGPoint(x: 52, y: 40))
                        path.move(to: CGPoint(x: 56, y: 22))
                        path.addLine(to: CGPoint(x: 38, y: 26))
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .foregroundStyle(Color.accentColor)
    }
}

struct PasswordEntryView: View {
    @Binding var password: String
    @Environment(\.dismiss) var dismiss
    @State private var input = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Set a password to encrypt this PDF when exporting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()

                SecureField("Password", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("Save Password") {
                    password = input
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.isEmpty)

                if !password.isEmpty {
                    Button("Remove Password") {
                        password = ""
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }

                Spacer()
            }
            .navigationTitle("PDF Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

struct PKCanvasViewWrapper: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}

struct PDFEditorContainer: UIViewRepresentable {
    @ObservedObject var controller: PDFEditorController
    let onRequestTextInput: (TextTarget) -> Void

    func makeUIView(context: Context) -> PDFSigningView {
        let view = PDFSigningView()
        view.configure()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: PDFSigningView, context: Context) {
        context.coordinator.update(uiView: uiView, controller: controller)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onRequestTextInput: onRequestTextInput)
    }
}

final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    private let parent: PDFEditorContainer
    private let onRequestTextInput: (TextTarget) -> Void
    private weak var pdfView: PDFView?
    private weak var imageOverlayView: UIView?
    private weak var canvasView: PKCanvasView?
    private var pageObserver: NSObjectProtocol?
    private var scaleObserver: NSObjectProtocol?
    private var contentOffsetObservation: NSKeyValueObservation?
    private var tapRecognizer: UITapGestureRecognizer?
    private var objectTapRecognizer: UITapGestureRecognizer?
    private var shapePanRecognizer: UIPanGestureRecognizer?
    private var shapePinchRecognizer: UIPinchGestureRecognizer?
    private weak var selectedShapeAnnotation: PDFAnnotation?
    private weak var selectedShapePage: PDFPage?
    private var selectedImageID: UUID?
    private var selectedImagePageIndex: Int?
    private var panStartBounds = CGRect.zero
    private var panStartPoint = CGPoint.zero
    private var pinchStartBounds = CGRect.zero
    private var pinchStartImageBounds = CGRect.zero
    private var pinchStartFontSize: CGFloat = 0

    init(_ parent: PDFEditorContainer, onRequestTextInput: @escaping (TextTarget) -> Void) {
        self.parent = parent
        self.onRequestTextInput = onRequestTextInput
        super.init()
    }

    deinit {
        if let pageObserver { NotificationCenter.default.removeObserver(pageObserver) }
        if let scaleObserver { NotificationCenter.default.removeObserver(scaleObserver) }
        contentOffsetObservation?.invalidate()
    }

    func attach(to view: PDFSigningView) {
        pdfView = view.pdfView
        imageOverlayView = view.imageOverlayView
        canvasView = view.canvasView
        canvasView?.delegate = self
        parent.controller.onSyncDrawing = { [weak self] in
            guard let self, let canvasView = self.canvasView else { return }
            self.parent.controller.setDrawing(
                canvasView.drawing,
                canvasSize: canvasView.bounds.size,
                forPage: self.parent.controller.currentPageIndex
            )
        }
        parent.controller.onApplyDrawing = { [weak self] drawing in
            self?.canvasView?.drawing = drawing
        }
        parent.controller.onUpdateTool = { [weak self] in
            self?.updatePKTool()
        }
        parent.controller.onDeleteSelectedEditableObject = { [weak self] in
            self?.deleteSelectedEditableAnnotation()
        }
        parent.controller.onDeselectEditableObject = { [weak self] in
            self?.selectedShapeAnnotation = nil
            self?.selectedShapePage = nil
            self?.selectedImageID = nil
            self?.selectedImagePageIndex = nil
        }
        parent.controller.onApplyTextStyleToSelectedObject = { [weak self] in
            self?.applyTextStyleToSelectedAnnotation()
        }
        parent.controller.onSelectTextAnnotation = { [weak self] annotation, pageIndex in
            self?.selectTextAnnotation(annotation, pageIndex: pageIndex)
        }
        parent.controller.onZoomIn = { [weak self] in
            self?.changeZoom(by: 1.35)
        }
        parent.controller.onZoomOut = { [weak self] in
            self?.changeZoom(by: 1 / 1.35)
        }
        parent.controller.onFitPage = { [weak self] in
            self?.fitPage()
        }
        view.onLayout = { [weak self] in
            self?.updateCanvasFrame()
        }

        if let pdfView {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tapRecognizer.cancelsTouchesInView = false
            pdfView.addGestureRecognizer(tapRecognizer)
            self.tapRecognizer = tapRecognizer

            let objectTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleObjectTap(_:)))
            objectTapRecognizer.cancelsTouchesInView = false
            objectTapRecognizer.delegate = self
            pdfView.addGestureRecognizer(objectTapRecognizer)
            self.objectTapRecognizer = objectTapRecognizer

            let shapePanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleShapePan(_:)))
            shapePanRecognizer.delegate = self
            pdfView.addGestureRecognizer(shapePanRecognizer)
            self.shapePanRecognizer = shapePanRecognizer

            let shapePinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handleShapePinch(_:)))
            shapePinchRecognizer.delegate = self
            pdfView.addGestureRecognizer(shapePinchRecognizer)
            self.shapePinchRecognizer = shapePinchRecognizer

            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.handlePageChange()
            }
            scaleObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                self?.updateCanvasFrame()
            }

            if let scrollView = findScrollView(in: pdfView) {
                contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.updateCanvasFrame()
                    }
                }
            }
        }
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) { return scrollView }
        }
        return nil
    }

    func update(uiView: PDFSigningView, controller: PDFEditorController) {
        guard let pdfView, let canvasView else { return }

        if pdfView.document !== controller.document {
            pdfView.document = controller.document
            pdfView.goToFirstPage(nil)
            if controller.currentPageIndex != 0 {
                DispatchQueue.main.async {
                    controller.currentPageIndex = 0
                }
            }
            canvasView.drawing = controller.drawing(forPage: 0)?.drawing ?? PKDrawing()
            DispatchQueue.main.async { [weak self] in
                self?.configureZoomRange(resetToFit: true)
                self?.updateCanvasFrame()
                self?.updateImageOverlay()
                self?.updatePKTool()
            }
        }

        if let document = pdfView.document,
           controller.currentPageIndex >= 0,
           controller.currentPageIndex < document.pageCount,
           let targetPage = document.page(at: controller.currentPageIndex),
           pdfView.currentPage !== targetPage {
            if let currentPage = pdfView.currentPage {
                let oldIndex = document.index(for: currentPage)
                parent.controller.setDrawing(canvasView.drawing, canvasSize: canvasView.bounds.size, forPage: oldIndex)
            }
            pdfView.go(to: targetPage)
            canvasView.drawing = controller.drawing(forPage: controller.currentPageIndex)?.drawing ?? PKDrawing()
            updateCanvasFrame()
            updateImageOverlay()
        }

        let drawingActive = controller.isDrawingActive
        pdfView.isUserInteractionEnabled = !drawingActive
        canvasView.isUserInteractionEnabled = drawingActive
        tapRecognizer?.isEnabled = controller.activeTool == .text || controller.activeTool == .correctText || controller.activeTool == .identifyFont
        objectTapRecognizer?.isEnabled = !drawingActive && controller.activeTool != .text && controller.activeTool != .correctText && controller.activeTool != .identifyFont
        shapePanRecognizer?.isEnabled = !drawingActive
        shapePinchRecognizer?.isEnabled = !drawingActive
        updateImageOverlay()
    }

    private func updatePKTool() {
        guard let canvasView else { return }
        let color = UIColor(parent.controller.selectedColor)

        switch parent.controller.drawingTool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: color, width: 3)
        case .marker:
            canvasView.tool = PKInkingTool(.marker, color: color.withAlphaComponent(0.5), width: 15)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard canvasView.bounds.width.isFinite, canvasView.bounds.height.isFinite else { return }
        parent.controller.setDrawing(
            canvasView.drawing,
            canvasSize: canvasView.bounds.size,
            forPage: parent.controller.currentPageIndex
        )
    }

    private func handlePageChange() {
        guard let pdfView, let canvasView, let document = pdfView.document, let page = pdfView.currentPage else { return }
        let newIndex = document.index(for: page)
        if newIndex == parent.controller.currentPageIndex { return }

        parent.controller.setDrawing(
            canvasView.drawing,
            canvasSize: canvasView.bounds.size,
            forPage: parent.controller.currentPageIndex
        )

        parent.controller.currentPageIndex = newIndex
        canvasView.drawing = parent.controller.drawing(forPage: newIndex)?.drawing ?? PKDrawing()
        updateCanvasFrame()
        updateImageOverlay()
    }

    private func updateCanvasFrame() {
        guard let pdfView, let canvasView, let page = pdfView.currentPage else { return }
        let pageBounds = page.bounds(for: pdfView.displayBox)
        let pageRect = pdfView.convert(pageBounds, from: page)
        guard !pageRect.isEmpty else { return }
        guard pageRect.width.isFinite, pageRect.height.isFinite else { return }
        guard pageRect.width > 1, pageRect.height > 1 else { return }
        let sizeChanged = canvasView.bounds.size != pageRect.size
        canvasView.frame = pageRect
        imageOverlayView?.frame = pdfView.bounds
        parent.controller.updateCurrentCanvasSize(pageRect.size)
        updateImageOverlay()

        if sizeChanged, let record = parent.controller.drawing(forPage: parent.controller.currentPageIndex) {
            guard record.canvasSize.width > 0, record.canvasSize.height > 0 else { return }
            let scaleX = pageRect.width / record.canvasSize.width
            let scaleY = pageRect.height / record.canvasSize.height
            if scaleX.isFinite, scaleY.isFinite, scaleX > 0.1, scaleY > 0.1, scaleX < 10, scaleY < 10 {
                let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                let scaledDrawing = record.drawing.transformed(using: transform)
                canvasView.drawing = scaledDrawing
            }
        }
    }

    private func updateImageOverlay() {
        guard let pdfView, let imageOverlayView else { return }
        imageOverlayView.subviews.forEach { $0.removeFromSuperview() }
        guard let page = pdfView.currentPage else { return }

        let images = parent.controller.images(forPage: parent.controller.currentPageIndex)
        for inserted in images {
            let imageView = InsertedImageOverlayView(image: inserted.image, insertedID: inserted.id, pageIndex: parent.controller.currentPageIndex)
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.isUserInteractionEnabled = true
            imageView.frame = pdfView.convert(inserted.bounds, from: page)
            guard imageView.frame.width > 1, imageView.frame.height > 1 else { continue }
            if inserted.id == selectedImageID {
                imageView.layer.borderColor = UIColor.systemBlue.cgColor
                imageView.layer.borderWidth = 2
                imageView.layer.cornerRadius = 6
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleImageOverlayTap(_:)))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleImageOverlayPan(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleImageOverlayPinch(_:)))
            pan.delegate = self
            pinch.delegate = self
            imageView.addGestureRecognizer(tap)
            imageView.addGestureRecognizer(pan)
            imageView.addGestureRecognizer(pinch)
            imageOverlayView.addSubview(imageView)
        }
    }

    private func configureZoomRange(resetToFit: Bool) {
        guard let pdfView else { return }
        pdfView.autoScales = true
        let fitScale = pdfView.scaleFactorForSizeToFit
        guard fitScale.isFinite, fitScale > 0.01 else { return }
        pdfView.minScaleFactor = fitScale * 0.75
        pdfView.maxScaleFactor = fitScale * 8
        if resetToFit {
            pdfView.scaleFactor = fitScale
        }
    }

    private func changeZoom(by multiplier: CGFloat) {
        guard let pdfView else { return }
        let target = pdfView.scaleFactor * multiplier
        pdfView.scaleFactor = min(pdfView.maxScaleFactor, max(pdfView.minScaleFactor, target))
        updateCanvasFrame()
    }

    private func fitPage() {
        configureZoomRange(resetToFit: true)
        updateCanvasFrame()
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard parent.controller.activeTool == .text || parent.controller.activeTool == .correctText || parent.controller.activeTool == .identifyFont else { return }
        guard let pdfView, let document = pdfView.document else { return }
        let location = recognizer.location(in: pdfView)
        guard let page = pdfView.page(for: location, nearest: true) else { return }
        let pagePoint = pdfView.convert(location, to: page)
        let pageIndex = document.index(for: page)

        if parent.controller.activeTool == .identifyFont {
            identifyFont(on: page, at: pagePoint)
            return
        }

        let existing = page.annotations.first { annotation in
            isSwiftPDFText(annotation) && annotation.bounds.contains(pagePoint)
        }

        if let existing {
            let mode: TextEditMode = PDFTextAnnotator.isCorrection(existing) ? .correction : .addition
            onRequestTextInput(
                TextTarget(
                    pageIndex: pageIndex,
                    point: pagePoint,
                    annotation: existing,
                    mode: mode,
                    sourceBounds: nil,
                    sourceText: nil
                )
            )
            return
        }

        if parent.controller.activeTool == .correctText {
            let selection = page.selectionForWord(at: pagePoint)
            let selectedBounds = selection?.bounds(for: page).standardized
            let usableBounds = selectedBounds.flatMap { bounds in
                bounds.isEmpty || !bounds.width.isFinite || !bounds.height.isFinite ? nil : bounds
            }
            if let usableBounds {
                parent.controller.textSize = max(8, min(72, usableBounds.height * 0.9))
            }
            onRequestTextInput(
                TextTarget(
                    pageIndex: pageIndex,
                    point: pagePoint,
                    annotation: nil,
                    mode: .correction,
                    sourceBounds: usableBounds,
                    sourceText: selection?.string
                )
            )
        } else {
            onRequestTextInput(
                TextTarget(
                    pageIndex: pageIndex,
                    point: pagePoint,
                    annotation: nil,
                    mode: .addition,
                    sourceBounds: nil,
                    sourceText: nil
                )
            )
        }
    }

    private func identifyFont(on page: PDFPage, at pagePoint: CGPoint) {
        if let selection = page.selectionForWord(at: pagePoint),
           let result = FontIdentifier.embeddedFontResult(from: selection) {
            parent.controller.fontIdentificationResult = result
            return
        }

        guard !parent.controller.isIdentifyingFont else { return }
        let pageBounds = page.bounds(for: pdfView?.displayBox ?? .mediaBox).standardized
        guard pageBounds.width > 1, pageBounds.height > 1 else { return }
        let renderWidth: CGFloat = 1600
        let renderSize = CGSize(width: renderWidth, height: renderWidth * pageBounds.height / pageBounds.width)
        let pageImage = page.thumbnail(of: renderSize, for: pdfView?.displayBox ?? .mediaBox)
        let normalizedPoint = CGPoint(
            x: (pagePoint.x - pageBounds.minX) / pageBounds.width,
            y: (pagePoint.y - pageBounds.minY) / pageBounds.height
        )

        parent.controller.isIdentifyingFont = true
        Task { [weak self] in
            let result = await FontIdentifier.scannedFontResult(
                in: pageImage,
                near: normalizedPoint,
                pageHeight: pageBounds.height
            )
            guard let self else { return }
            await MainActor.run {
                self.parent.controller.isIdentifyingFont = false
                if let result {
                    self.parent.controller.fontIdentificationResult = result
                } else {
                    self.parent.controller.fontIdentificationResult = FontIdentificationResult(
                        detectedName: "No readable text found",
                        closestFamily: .system,
                        size: self.parent.controller.textSize,
                        bold: false,
                        italic: false,
                        isEmbeddedFont: false,
                        matchFound: false
                    )
                }
            }
        }
    }

    @objc private func handleObjectTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let location = recognizer.location(in: pdfView)
        if let hit = editableImage(at: location) {
            selectedShapeAnnotation = nil
            selectedShapePage = nil
            selectedImageID = hit.image.id
            selectedImagePageIndex = hit.pageIndex
            parent.controller.selectEditableObject(label: hit.image.label)
            updateImageOverlay()
            return
        }
        guard let hit = editableAnnotation(at: location) else {
            parent.controller.clearEditableObjectSelection()
            return
        }
        selectedImageID = nil
        selectedImagePageIndex = nil
        selectedShapeAnnotation = hit.annotation
        selectedShapePage = hit.page
        if isSwiftPDFText(hit.annotation) {
            PDFTextAnnotator.syncControllerStyle(from: hit.annotation, into: parent.controller)
        }
        parent.controller.selectEditableObject(label: editableLabel(for: hit.annotation))
    }

    @objc private func handleImageOverlayTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let imageView = recognizer.view as? InsertedImageOverlayView,
              let inserted = parent.controller.images(forPage: imageView.pageIndex).first(where: { $0.id == imageView.insertedID }) else { return }

        selectedShapeAnnotation = nil
        selectedShapePage = nil
        selectedImageID = inserted.id
        selectedImagePageIndex = imageView.pageIndex
        parent.controller.selectEditableObject(label: inserted.label)
        updateImageOverlay()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pdfView else { return false }
        guard !parent.controller.isDrawingActive else { return false }

        if gestureRecognizer === shapePanRecognizer {
            let location = gestureRecognizer.location(in: pdfView)
            if let hit = editableImage(at: location) {
                selectedShapeAnnotation = nil
                selectedShapePage = nil
                selectedImageID = hit.image.id
                selectedImagePageIndex = hit.pageIndex
                parent.controller.selectEditableObject(label: hit.image.label)
                updateImageOverlay()
                return true
            }

            guard let hit = editableAnnotation(at: location) else {
                selectedShapeAnnotation = nil
                selectedShapePage = nil
                selectedImageID = nil
                selectedImagePageIndex = nil
                return false
            }
            selectedImageID = nil
            selectedImagePageIndex = nil
            selectedShapeAnnotation = hit.annotation
            selectedShapePage = hit.page
            if isSwiftPDFText(hit.annotation) {
                PDFTextAnnotator.syncControllerStyle(from: hit.annotation, into: parent.controller)
            }
            parent.controller.selectEditableObject(label: editableLabel(for: hit.annotation))
            return true
        }

        if gestureRecognizer === shapePinchRecognizer {
            return selectedShapeAnnotation != nil || selectedImageID != nil
        }

        return true
    }

    @objc private func handleShapePan(_ recognizer: UIPanGestureRecognizer) {
        if selectedImageID != nil {
            handleImagePan(recognizer)
            return
        }

        guard let pdfView, let annotation = selectedShapeAnnotation, let page = selectedShapePage else { return }
        let location = recognizer.location(in: pdfView)
        let pagePoint = pdfView.convert(location, to: page)

        switch recognizer.state {
        case .began:
            panStartBounds = annotation.bounds
            panStartPoint = pagePoint
        case .changed:
            let dx = pagePoint.x - panStartPoint.x
            let dy = pagePoint.y - panStartPoint.y
            updateEditableAnnotation(annotation, on: page, bounds: panStartBounds.offsetBy(dx: dx, dy: dy))
        default:
            parent.controller.objectWillChange.send()
        }
    }

    @objc private func handleImageOverlayPan(_ recognizer: UIPanGestureRecognizer) {
        guard let imageView = recognizer.view as? InsertedImageOverlayView else { return }
        selectOverlayImageIfNeeded(imageView)
        handleImagePan(recognizer)
    }

    @objc private func handleShapePinch(_ recognizer: UIPinchGestureRecognizer) {
        if selectedImageID != nil {
            handleImagePinch(recognizer)
            return
        }

        guard let annotation = selectedShapeAnnotation, let page = selectedShapePage else { return }
        switch recognizer.state {
        case .began:
            pinchStartBounds = annotation.bounds
            pinchStartFontSize = annotation.font?.pointSize ?? 0
        case .changed:
            let scale = max(0.25, min(4.0, recognizer.scale))
            let newWidth = max(24, pinchStartBounds.width * scale)
            let newHeight = max(24, pinchStartBounds.height * scale)
            let center = CGPoint(x: pinchStartBounds.midX, y: pinchStartBounds.midY)
            let newBounds = CGRect(
                x: center.x - newWidth * 0.5,
                y: center.y - newHeight * 0.5,
                width: newWidth,
                height: newHeight
            )
            if isSwiftPDFText(annotation), pinchStartFontSize > 0 {
                let font = annotation.font ?? UIFont.systemFont(ofSize: pinchStartFontSize)
                annotation.font = font.withSize(max(8, min(72, pinchStartFontSize * scale)))
            }
            updateEditableAnnotation(annotation, on: page, bounds: newBounds)
        default:
            parent.controller.objectWillChange.send()
        }
    }

    @objc private func handleImageOverlayPinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let imageView = recognizer.view as? InsertedImageOverlayView else { return }
        selectOverlayImageIfNeeded(imageView)
        handleImagePinch(recognizer)
    }

    private func selectOverlayImageIfNeeded(_ imageView: InsertedImageOverlayView) {
        guard selectedImageID != imageView.insertedID || selectedImagePageIndex != imageView.pageIndex else { return }
        guard let inserted = parent.controller.images(forPage: imageView.pageIndex).first(where: { $0.id == imageView.insertedID }) else { return }
        selectedShapeAnnotation = nil
        selectedShapePage = nil
        selectedImageID = inserted.id
        selectedImagePageIndex = imageView.pageIndex
        parent.controller.selectEditableObject(label: inserted.label)
    }

    private func handleImagePan(_ recognizer: UIPanGestureRecognizer) {
        guard let pdfView,
              let page = pdfView.currentPage,
              let hitImage = selectedImage(),
              let pageIndex = selectedImagePageIndex else { return }

        let location = recognizer.location(in: pdfView)
        let pagePoint = pdfView.convert(location, to: page)

        switch recognizer.state {
        case .began:
            panStartBounds = hitImage.bounds
            panStartPoint = pagePoint
        case .changed:
            let dx = pagePoint.x - panStartPoint.x
            let dy = pagePoint.y - panStartPoint.y
            let pageBounds = page.bounds(for: .mediaBox).standardized
            let newBounds = clamp(panStartBounds.offsetBy(dx: dx, dy: dy), to: pageBounds)
            parent.controller.updateImage(id: hitImage.id, onPage: pageIndex, bounds: newBounds, notify: false)
            recognizer.view?.frame = pdfView.convert(newBounds, from: page)
        default:
            parent.controller.updateImage(id: hitImage.id, onPage: pageIndex, bounds: selectedImage()?.bounds ?? hitImage.bounds)
            updateImageOverlay()
        }
    }

    private func handleImagePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let pdfView,
              let page = pdfView.currentPage,
              let hitImage = selectedImage(),
              let pageIndex = selectedImagePageIndex else { return }

        switch recognizer.state {
        case .began:
            pinchStartImageBounds = hitImage.bounds
        case .changed:
            let scale = max(0.25, min(4.0, recognizer.scale))
            let newWidth = max(32, pinchStartImageBounds.width * scale)
            let newHeight = max(24, pinchStartImageBounds.height * scale)
            let center = CGPoint(x: pinchStartImageBounds.midX, y: pinchStartImageBounds.midY)
            let proposed = CGRect(
                x: center.x - newWidth * 0.5,
                y: center.y - newHeight * 0.5,
                width: newWidth,
                height: newHeight
            )
            let pageBounds = page.bounds(for: .mediaBox).standardized
            let newBounds = clamp(proposed, to: pageBounds)
            parent.controller.updateImage(id: hitImage.id, onPage: pageIndex, bounds: newBounds, notify: false)
            recognizer.view?.frame = pdfView.convert(newBounds, from: page)
        default:
            parent.controller.updateImage(id: hitImage.id, onPage: pageIndex, bounds: selectedImage()?.bounds ?? hitImage.bounds)
            updateImageOverlay()
        }
    }

    private func selectedImage() -> PDFEditorController.InsertedImage? {
        guard let selectedImageID, let selectedImagePageIndex else { return nil }
        return parent.controller.images(forPage: selectedImagePageIndex).first { $0.id == selectedImageID }
    }

    private func editableAnnotation(at location: CGPoint) -> (page: PDFPage, annotation: PDFAnnotation)? {
        guard let pdfView, let page = pdfView.page(for: location, nearest: true) else { return nil }
        let pagePoint = pdfView.convert(location, to: page)
        return page.annotations.reversed().first { annotation in
            isEditableAnnotation(annotation) && annotation.bounds.insetBy(dx: -20, dy: -20).contains(pagePoint)
        }.map { (page, $0) }
    }

    private func editableImage(at location: CGPoint) -> (pageIndex: Int, image: PDFEditorController.InsertedImage)? {
        guard let pdfView, let document = pdfView.document,
              let page = pdfView.page(for: location, nearest: true) else { return nil }

        let pageIndex = document.index(for: page)
        guard pageIndex >= 0 else { return nil }

        let images = parent.controller.images(forPage: pageIndex)
        return images.reversed().first { inserted in
            let frame = pdfView.convert(inserted.bounds, from: page)
            return frame.insetBy(dx: -24, dy: -24).contains(location)
        }.map { (pageIndex, $0) }
    }

    private func updateEditableAnnotation(_ annotation: PDFAnnotation, on page: PDFPage, bounds: CGRect) {
        let pageBounds = page.bounds(for: .mediaBox).standardized
        let clamped = clamp(bounds.standardized, to: pageBounds)
        annotation.bounds = clamped
        if isSwiftPDFShape(annotation), annotation.type == PDFAnnotationSubtype.line.rawValue {
            annotation.startPoint = CGPoint(x: clamped.minX, y: clamped.maxY)
            annotation.endPoint = CGPoint(x: clamped.maxX, y: clamped.minY)
        }
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
        selectedShapeAnnotation = annotation
        selectedShapePage = page
        parent.controller.selectEditableObject(label: editableLabel(for: annotation))
        parent.controller.objectWillChange.send()
    }

    private func selectTextAnnotation(_ annotation: PDFAnnotation, pageIndex: Int) {
        guard let document = pdfView?.document,
              let page = document.page(at: pageIndex) else { return }
        selectedImageID = nil
        selectedImagePageIndex = nil
        selectedShapeAnnotation = annotation
        selectedShapePage = page
        PDFTextAnnotator.syncControllerStyle(from: annotation, into: parent.controller)
        parent.controller.selectEditableObject(label: PDFTextAnnotator.isCorrection(annotation) ? "Correction" : "Text")
    }

    private func applyTextStyleToSelectedAnnotation() {
        guard let annotation = selectedShapeAnnotation,
              let page = selectedShapePage,
              isSwiftPDFText(annotation) else { return }
        PDFTextAnnotator.applyCurrentStyle(to: annotation, controller: parent.controller)
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
        selectedShapeAnnotation = annotation
        selectedShapePage = page
        parent.controller.selectEditableObject(label: PDFTextAnnotator.isCorrection(annotation) ? "Correction" : "Text")
        parent.controller.drawingVersion += 1
        parent.controller.objectWillChange.send()
        refreshPDFDisplay()
    }

    private func deleteSelectedEditableAnnotation() {
        if let selectedImageID, let selectedImagePageIndex {
            parent.controller.deleteImage(id: selectedImageID, onPage: selectedImagePageIndex)
            self.selectedImageID = nil
            self.selectedImagePageIndex = nil
            parent.controller.hasSelectedEditableObject = false
            parent.controller.selectedEditableObjectLabel = ""
            updateImageOverlay()
            return
        }

        guard let annotation = selectedShapeAnnotation, let page = selectedShapePage else {
            parent.controller.clearEditableObjectSelection()
            return
        }
        page.removeAnnotation(annotation)
        selectedShapeAnnotation = nil
        selectedShapePage = nil
        parent.controller.hasSelectedEditableObject = false
        parent.controller.selectedEditableObjectLabel = ""
        parent.controller.drawingVersion += 1
    }

    private func refreshPDFDisplay() {
        pdfView?.setNeedsDisplay()
        pdfView?.documentView?.setNeedsDisplay()
        pdfView?.layoutDocumentView()
    }

    private func clamp(_ rect: CGRect, to pageBounds: CGRect) -> CGRect {
        let width = min(max(24, rect.width), pageBounds.width)
        let height = min(max(24, rect.height), pageBounds.height)
        let x = min(max(rect.minX, pageBounds.minX), pageBounds.maxX - width)
        let y = min(max(rect.minY, pageBounds.minY), pageBounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func isSwiftPDFShape(_ annotation: PDFAnnotation) -> Bool {
        guard let userName = annotation.userName else { return false }
        return userName == "SwiftPDFShape" || userName.hasPrefix("SwiftPDFShape:")
    }

    private func isSwiftPDFText(_ annotation: PDFAnnotation) -> Bool {
        guard let userName = annotation.userName else { return false }
        return userName == "SwiftPDFText" || userName.hasPrefix("SwiftPDFText|") || userName.hasPrefix("SwiftPDFText:")
    }

    private func isEditableAnnotation(_ annotation: PDFAnnotation) -> Bool {
        isSwiftPDFShape(annotation) || isSwiftPDFText(annotation)
    }

    private func editableLabel(for annotation: PDFAnnotation) -> String {
        if PDFTextAnnotator.isCorrection(annotation) { return "Correction" }
        if isSwiftPDFText(annotation) { return "Text" }
        return "Shape"
    }
}

final class PassthroughOverlayView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(convertedPoint, with: event) {
                return hitView
            }
        }
        return nil
    }
}

final class InsertedImageOverlayView: UIImageView {
    let insertedID: UUID
    let pageIndex: Int

    init(image: UIImage, insertedID: UUID, pageIndex: Int) {
        self.insertedID = insertedID
        self.pageIndex = pageIndex
        super.init(image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PDFSigningView: UIView {
    let pdfView = PDFView()
    let imageOverlayView = PassthroughOverlayView()
    let canvasView = PKCanvasView()
    var onLayout: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure() {
        backgroundColor = .systemBackground

        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displaysAsBook = false
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        pdfView.pageShadowsEnabled = false
        pdfView.isUserInteractionEnabled = true
        pdfView.enableDataDetectors = true

        addSubview(pdfView)

        imageOverlayView.backgroundColor = .clear
        imageOverlayView.isUserInteractionEnabled = true
        addSubview(imageOverlayView)

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.isScrollEnabled = false
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)

        addSubview(canvasView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pdfView.frame = bounds
        imageOverlayView.frame = bounds
        onLayout?()
    }
}

enum PDFTextAnnotator {
    static func addOrUpdateText(_ text: String, target: TextTarget, document: PDFDocument?, controller: PDFEditorController) -> PDFAnnotation? {
        guard let document, let page = document.page(at: target.pageIndex) else { return nil }

        let correction = target.mode == .correction || target.annotation.map { isCorrection($0) } == true

        let font = font(
            family: controller.textFontFamily,
            size: controller.textSize,
            bold: controller.textBold,
            italic: controller.textItalic
        )
        let color = UIColor(controller.textColor)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let measured = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 6
        let width = max(40, measured.width + padding * 2)
        let height = max(24, measured.height + padding * 1.5)

        let correctionBounds = target.sourceBounds.map {
            $0.insetBy(dx: -3, dy: -2)
        }
        let anchor = target.annotation.map {
            CGPoint(x: $0.bounds.midX, y: $0.bounds.midY)
        } ?? correctionBounds.map {
            CGPoint(x: $0.midX, y: $0.midY)
        } ?? target.point
        let targetWidth = max(width, correctionBounds?.width ?? (correction ? 120 : 0))
        let targetHeight = max(height, correctionBounds?.height ?? (correction ? 28 : 0))
        var origin = CGPoint(x: anchor.x - targetWidth * 0.5, y: anchor.y - targetHeight * 0.5)
        let pageBounds = page.bounds(for: .mediaBox)
        origin.x = max(pageBounds.minX + 4, min(origin.x, pageBounds.maxX - targetWidth - 4))
        origin.y = max(pageBounds.minY + 4, min(origin.y, pageBounds.maxY - targetHeight - 4))

        if let annotation = target.annotation {
            annotation.font = font
            annotation.fontColor = color
            annotation.color = correction ? UIColor(controller.correctionBackgroundColor) : .clear
            annotation.alignment = .left
            annotation.contents = text
            annotation.userName = textUserName(controller: controller, correction: correction)
            annotation.bounds = CGRect(origin: origin, size: CGSize(width: targetWidth, height: targetHeight))
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            return annotation
        } else {
            let annotation = PDFAnnotation(
                bounds: CGRect(origin: origin, size: CGSize(width: targetWidth, height: targetHeight)),
                forType: .freeText,
                withProperties: nil
            )
            annotation.font = font
            annotation.fontColor = color
            annotation.color = correction ? UIColor(controller.correctionBackgroundColor) : .clear
            annotation.alignment = .left
            annotation.contents = text
            annotation.userName = textUserName(controller: controller, correction: correction)
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            page.addAnnotation(annotation)
            return annotation
        }
    }

    static func applyCurrentStyle(to annotation: PDFAnnotation, controller: PDFEditorController) {
        let text = annotation.contents ?? ""
        let correction = isCorrection(annotation)
        let font = font(
            family: controller.textFontFamily,
            size: controller.textSize,
            bold: controller.textBold,
            italic: controller.textItalic
        )
        annotation.font = font
        annotation.fontColor = UIColor(controller.textColor)
        annotation.color = correction ? UIColor(controller.correctionBackgroundColor) : .clear
        annotation.alignment = .left
        annotation.userName = textUserName(controller: controller, correction: correction)
        annotation.shouldDisplay = true
        annotation.shouldPrint = true

        guard !text.isEmpty else { return }
        let measured = (text as NSString).size(withAttributes: [.font: font])
        let padding: CGFloat = 6
        let width = max(40, measured.width + padding * 2)
        let height = max(24, measured.height + padding * 1.5)
        let center = CGPoint(x: annotation.bounds.midX, y: annotation.bounds.midY)
        annotation.bounds = CGRect(
            x: center.x - width * 0.5,
            y: center.y - height * 0.5,
            width: width,
            height: height
        )
    }

    @MainActor
    static func syncControllerStyle(from annotation: PDFAnnotation, into controller: PDFEditorController) {
        if let font = annotation.font {
            controller.textSize = font.pointSize
            controller.textBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            controller.textItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            controller.textFontFamily = family(for: font)
        }
        if let color = annotation.fontColor {
            controller.textColor = Color(color)
        }
        if isCorrection(annotation) {
            controller.correctionBackgroundColor = Color(correctionBackgroundColor(for: annotation))
        }
        controller.textStrikethrough = textStyleFlag("strike", in: annotation)
    }

    nonisolated static func font(family: TextFontFamily, size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        let base: UIFont
        switch family {
        case .system:
            base = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        case .helvetica:
            base = namedFont(
                regular: "Helvetica",
                bold: "Helvetica-Bold",
                italic: "Helvetica-Oblique",
                boldItalic: "Helvetica-BoldOblique",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .arial:
            base = namedFont(
                regular: "ArialMT",
                bold: "Arial-BoldMT",
                italic: "Arial-ItalicMT",
                boldItalic: "Arial-BoldItalicMT",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .timesNewRoman, .serif:
            base = namedFont(
                regular: "TimesNewRomanPSMT",
                bold: "TimesNewRomanPS-BoldMT",
                italic: "TimesNewRomanPS-ItalicMT",
                boldItalic: "TimesNewRomanPS-BoldItalicMT",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .georgia:
            base = namedFont(
                regular: "Georgia",
                bold: "Georgia-Bold",
                italic: "Georgia-Italic",
                boldItalic: "Georgia-BoldItalic",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .avenir:
            base = namedFont(
                regular: "AvenirNext-Regular",
                bold: "AvenirNext-DemiBold",
                italic: "AvenirNext-Italic",
                boldItalic: "AvenirNext-DemiBoldItalic",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .futura:
            base = namedFont(
                regular: "Futura-Medium",
                bold: "Futura-Bold",
                italic: "Futura-MediumItalic",
                boldItalic: "Futura-Bold",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .courier:
            base = namedFont(
                regular: "Courier",
                bold: "Courier-Bold",
                italic: "Courier-Oblique",
                boldItalic: "Courier-BoldOblique",
                size: size,
                wantsBold: bold,
                wantsItalic: italic
            )
        case .rounded:
            let descriptor = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular).fontDescriptor
            let roundedDescriptor = descriptor.withDesign(.rounded) ?? descriptor
            base = UIFont(descriptor: roundedDescriptor, size: size)
        case .mono:
            base = UIFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        }

        guard italic else { return base }
        var traits = base.fontDescriptor.symbolicTraits
        traits.insert(.traitItalic)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    nonisolated private static func namedFont(
        regular: String,
        bold: String,
        italic: String,
        boldItalic: String,
        size: CGFloat,
        wantsBold: Bool,
        wantsItalic: Bool
    ) -> UIFont {
        let name: String
        if wantsBold && wantsItalic {
            name = boldItalic
        } else if wantsBold {
            name = bold
        } else if wantsItalic {
            name = italic
        } else {
            name = regular
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: wantsBold ? .bold : .regular)
    }

    nonisolated static func family(for font: UIFont) -> TextFontFamily {
        let name = font.fontName.lowercased()
        if name.contains("helvetica") { return .helvetica }
        if name.contains("arial") { return .arial }
        if name.contains("times") { return .timesNewRoman }
        if name.contains("georgia") { return .georgia }
        if name.contains("avenir") { return .avenir }
        if name.contains("futura") { return .futura }
        if name.contains("courier") { return .courier }
        if name.contains("mono") { return .mono }
        if font.fontDescriptor.object(forKey: .face) as? String == "UICTFontTextStyleBody" { return .system }
        return .system
    }

    private static func textStyleFlag(_ key: String, in annotation: PDFAnnotation) -> Bool {
        guard let userName = annotation.userName else { return false }
        return userName
            .split(separator: "|")
            .contains { $0 == "\(key)=1" }
    }

    static func isCorrection(_ annotation: PDFAnnotation) -> Bool {
        guard let userName = annotation.userName else { return false }
        return userName
            .split(separator: "|")
            .contains { $0 == "correction=1" }
    }

    static func correctionBackgroundColor(for annotation: PDFAnnotation) -> UIColor {
        guard let userName = annotation.userName,
              let value = userName
                .split(separator: "|")
                .first(where: { $0.hasPrefix("background=") })?
                .split(separator: "=", maxSplits: 1)
                .last else {
            return annotation.color == .clear ? .white : annotation.color
        }
        return color(fromHex: String(value)) ?? .white
    }

    private static func textUserName(controller: PDFEditorController, correction: Bool) -> String {
        var parts = [
            "SwiftPDFText",
            "font=\(controller.textFontFamily.rawValue)",
            "bold=\(controller.textBold ? 1 : 0)",
            "italic=\(controller.textItalic ? 1 : 0)",
            "strike=\(controller.textStrikethrough ? 1 : 0)"
        ]
        if correction {
            parts.append("correction=1")
            parts.append("background=\(hexColor(UIColor(controller.correctionBackgroundColor)))")
        }
        return parts.joined(separator: "|")
    }

    private static func hexColor(_ color: UIColor) -> String {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }

    private static func color(fromHex value: String) -> UIColor? {
        guard value.count == 6, let number = UInt64(value, radix: 16) else { return nil }
        return UIColor(
            red: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum FontIdentifier {
    static func embeddedFontResult(from selection: PDFSelection) -> FontIdentificationResult? {
        guard let attributed = selection.attributedString, attributed.length > 0 else { return nil }
        var detectedFont: UIFont?
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, stop in
            if let font = value as? UIFont {
                detectedFont = font
                stop.pointee = true
            }
        }
        guard let font = detectedFont else { return nil }
        let traits = font.fontDescriptor.symbolicTraits
        return FontIdentificationResult(
            detectedName: font.fontName,
            closestFamily: PDFTextAnnotator.family(for: font),
            size: font.pointSize,
            bold: traits.contains(.traitBold),
            italic: traits.contains(.traitItalic),
            isEmbeddedFont: true
        )
    }

    nonisolated static func scannedFontResult(
        in image: UIImage,
        near normalizedPoint: CGPoint,
        pageHeight: CGFloat? = nil
    ) async -> FontIdentificationResult? {
        await Task.detached(priority: .userInitiated) {
            identifyScannedFont(in: image, near: normalizedPoint, pageHeight: pageHeight)
        }.value
    }

    nonisolated private static func identifyScannedFont(
        in image: UIImage,
        near normalizedPoint: CGPoint,
        pageHeight: CGFloat?
    ) -> FontIdentificationResult? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results,
              let observation = closestObservation(to: normalizedPoint, in: observations),
              let recognized = observation.topCandidates(1).first,
              !recognized.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let crop = crop(image: cgImage, normalizedBounds: observation.boundingBox) else {
            return nil
        }

        guard let sourcePrint = featurePrint(for: crop) else { return nil }
        var best: (family: TextFontFamily, bold: Bool, italic: Bool, distance: Float)?
        let styles = [(false, false), (true, false), (false, true), (true, true)]

        let candidateFamilies: [TextFontFamily] = [
            .system, .helvetica, .arial, .timesNewRoman, .georgia,
            .avenir, .futura, .courier, .rounded, .mono
        ]
        for family in candidateFamilies {
            for (bold, italic) in styles {
                guard let candidate = renderedSample(
                    recognized.string,
                    family: family,
                    bold: bold,
                    italic: italic,
                    matching: crop.size
                ), let candidatePrint = featurePrint(for: candidate) else { continue }
                var distance: Float = 0
                try? sourcePrint.computeDistance(&distance, to: candidatePrint)
                if best == nil || distance < best!.distance {
                    best = (family, bold, italic, distance)
                }
            }
        }

        guard let best else { return nil }
        let estimatedSize = max(
            8,
            min(72, observation.boundingBox.height * (pageHeight ?? CGFloat(cgImage.height)) * 0.78)
        )
        return FontIdentificationResult(
            detectedName: recognized.string,
            closestFamily: best.family,
            size: estimatedSize,
            bold: best.bold,
            italic: best.italic,
            isEmbeddedFont: false
        )
    }

    nonisolated private static func closestObservation(
        to point: CGPoint,
        in observations: [VNRecognizedTextObservation]
    ) -> VNRecognizedTextObservation? {
        observations.min { lhs, rhs in
            distance(from: point, to: lhs.boundingBox) < distance(from: point, to: rhs.boundingBox)
        }
    }

    nonisolated private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    nonisolated private static func crop(image: CGImage, normalizedBounds: CGRect) -> UIImage? {
        let expanded = normalizedBounds.insetBy(dx: -0.012, dy: -0.025).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let rect = CGRect(
            x: expanded.minX * CGFloat(image.width),
            y: (1 - expanded.maxY) * CGFloat(image.height),
            width: expanded.width * CGFloat(image.width),
            height: expanded.height * CGFloat(image.height)
        ).integral
        guard rect.width > 4, rect.height > 4, let cropped = image.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }

    nonisolated private static func renderedSample(
        _ text: String,
        family: TextFontFamily,
        bold: Bool,
        italic: Bool,
        matching sourceSize: CGSize
    ) -> UIImage? {
        guard sourceSize.width > 4, sourceSize.height > 4 else { return nil }
        let scale = min(1, 512 / sourceSize.width, 160 / sourceSize.height)
        let size = CGSize(width: max(16, sourceSize.width * scale), height: max(16, sourceSize.height * scale))
        let horizontalPadding = max(2, size.width * 0.02)
        let verticalPadding = max(2, size.height * 0.06)
        var pointSize = size.height
        var font = PDFTextAnnotator.font(family: family, size: pointSize, bold: bold, italic: italic)
        let available = CGSize(width: size.width - horizontalPadding * 2, height: size.height - verticalPadding * 2)
        let measured = (text as NSString).size(withAttributes: [.font: font])
        if measured.width > 0, measured.height > 0 {
            pointSize *= min(available.width / measured.width, available.height / measured.height)
            font = PDFTextAnnotator.font(family: family, size: max(4, pointSize), bold: bold, italic: italic)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let finalSize = (text as NSString).size(withAttributes: [.font: font])
            let origin = CGPoint(
                x: max(horizontalPadding, (size.width - finalSize.width) * 0.5),
                y: max(verticalPadding, (size.height - finalSize.height) * 0.5)
            )
            (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: UIColor.black])
        }
    }

    nonisolated private static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil else { return nil }
        return request.results?.first as? VNFeaturePrintObservation
    }
}

enum PDFExporter {
    private static let logger = Logger(subsystem: "JimWas.SwiftPDF", category: "PDFExporter")

    static func flatten(document: PDFDocument, drawings: [Int: PageDrawing], images: [Int: [PDFEditorController.InsertedImage]], password: String = "", quality: CGFloat = 1.0) -> Data? {
        guard let baseData = document.dataRepresentation() else {
            logger.error("Failed to get data representation of source document")
            return nil
        }

        // We use renderFallback for everything now because it produces higher quality than PDFKit's native flatten
        guard let data = renderFallback(baseData: baseData, drawings: drawings, images: images, quality: quality) else {
            logger.error("renderFallback failed to produce flattened PDF data")
            return nil
        }

        if !password.isEmpty {
            let doc = PDFDocument(data: data)
            let options: [AnyHashable: Any] = [
                PDFDocumentWriteOption.userPasswordOption: password,
                PDFDocumentWriteOption.ownerPasswordOption: password
            ]
            guard let encrypted = doc?.dataRepresentation(options: options) else {
                logger.error("Failed to apply password encryption to exported PDF")
                return nil
            }
            return encrypted
        }

        return data
    }

    private static func writeAndRead(document: PDFDocument) -> Data? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("swiftpdf-export-\(UUID().uuidString).pdf")
        guard document.write(to: tempURL) else { return nil }
        let data = try? Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        return data
    }

    private static func needsFallback(_ data: Data) -> Bool {
        guard let marker = "/MediaBox [0 0 1 1]".data(using: .ascii) else { return false }
        return data.range(of: marker) != nil
    }

    private static func renderFallback(baseData: Data, drawings: [Int: PageDrawing], images: [Int: [PDFEditorController.InsertedImage]], quality: CGFloat) -> Data? {
        guard let document = PDFDocument(data: baseData),
              document.pageCount > 0,
              let firstPage = document.page(at: 0) else {
            return nil
        }
        let firstGeometry = pageGeometry(for: firstPage)
        guard !firstGeometry.rect.isEmpty else { return nil }

        let renderer = UIGraphicsPDFRenderer(bounds: firstGeometry.rect)
        return renderer.pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let geometry = pageGeometry(for: page)
                let pageRect = geometry.rect
                guard !pageRect.isEmpty else { continue }

                context.beginPage(withBounds: pageRect, pageInfo: [:])

                drawBasePage(page, box: geometry.box, pageRect: pageRect, in: context.cgContext)
                drawUserTextAnnotations(on: page, pageRect: pageRect, pageBounds: page.bounds(for: geometry.box).standardized)
                drawUserShapeAnnotations(on: page, pageRect: pageRect, pageBounds: page.bounds(for: geometry.box).standardized, in: context.cgContext)

                if let pageImages = images[index] {
                    drawImages(pageImages, pageRect: pageRect, pageBounds: page.bounds(for: geometry.box).standardized, quality: quality)
                }

                guard let record = drawings[index] else { continue }
                draw(record: record, in: context.cgContext, pageRect: pageRect, quality: quality)
            }
        }
    }

    private static func pageGeometry(for page: PDFPage) -> (rect: CGRect, box: PDFDisplayBox) {
        let media = page.bounds(for: .mediaBox).standardized
        if media.width.isFinite, media.height.isFinite, media.width > 1, media.height > 1 {
            return (CGRect(origin: .zero, size: media.size), .mediaBox)
        }
        let crop = page.bounds(for: .cropBox).standardized
        if crop.width.isFinite, crop.height.isFinite, crop.width > 1, crop.height > 1 {
            return (CGRect(origin: .zero, size: crop.size), .cropBox)
        }
        return (.zero, .mediaBox)
    }

    private static func drawBasePage(_ page: PDFPage, box: PDFDisplayBox, pageRect: CGRect, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)

        // PDFKit's draw(with:to:) takes care of the coordinate system flip relative to pageRect
        page.draw(with: box, to: context)

        context.restoreGState()
    }

    private static func drawUserTextAnnotations(on page: PDFPage, pageRect: CGRect, pageBounds: CGRect) {
        guard !pageBounds.isEmpty else { return }
        for annotation in page.annotations {
            if annotation.userName == "SwiftPDFWatermark" || annotation.userName == "SwiftPDFText" || annotation.userName?.hasPrefix("SwiftPDFText|") == true {
                guard let text = annotation.contents, !text.isEmpty else { continue }
                let font = annotation.font ?? UIFont.systemFont(ofSize: 16)
                let color = annotation.fontColor ?? .black
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = annotation.alignment
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph,
                    .strikethroughStyle: textStyleFlag("strike", in: annotation) ? NSUnderlineStyle.single.rawValue : 0
                ]

                let source = annotation.bounds
                let x = source.minX - pageBounds.minX
                let y = pageBounds.maxY - source.maxY
                let drawRect = CGRect(x: x, y: y, width: source.width, height: source.height)
                guard drawRect.width > 0, drawRect.height > 0 else { continue }
                guard drawRect.maxX >= 0, drawRect.minX <= pageRect.width else { continue }
                guard drawRect.maxY >= 0, drawRect.minY <= pageRect.height else { continue }
                if PDFTextAnnotator.isCorrection(annotation) {
                    PDFTextAnnotator.correctionBackgroundColor(for: annotation).setFill()
                    UIRectFill(drawRect)
                }
                (text as NSString).draw(in: drawRect, withAttributes: attributes)
            }
        }
    }

    private static func textStyleFlag(_ key: String, in annotation: PDFAnnotation) -> Bool {
        guard let userName = annotation.userName else { return false }
        return userName
            .split(separator: "|")
            .contains { $0 == "\(key)=1" }
    }

    private static func drawUserShapeAnnotations(on page: PDFPage, pageRect: CGRect, pageBounds: CGRect, in context: CGContext) {
        guard !pageBounds.isEmpty else { return }
        for annotation in page.annotations where annotation.userName == "SwiftPDFShape" || annotation.userName?.hasPrefix("SwiftPDFShape:") == true {
            let source = annotation.bounds
            let x = source.minX - pageBounds.minX
            let y = pageBounds.maxY - source.maxY
            let drawRect = CGRect(x: x, y: y, width: source.width, height: source.height)

            context.saveGState()
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(2.0)

            if annotation.type == PDFAnnotationSubtype.square.rawValue {
                context.stroke(drawRect)
            } else if annotation.type == PDFAnnotationSubtype.circle.rawValue {
                context.strokeEllipse(in: drawRect)
            } else if annotation.type == PDFAnnotationSubtype.line.rawValue {
                let start = CGPoint(x: drawRect.minX, y: drawRect.maxY)
                let end = CGPoint(x: drawRect.maxX, y: drawRect.minY)
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()

                if annotation.endLineStyle == .closedArrow {
                    drawArrowhead(from: start, to: end, color: annotation.color, in: context)
                }
            }

            context.restoreGState()
        }
    }

    private static func drawArrowhead(from start: CGPoint, to end: CGPoint, color: UIColor, in context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 12
        let headAngle: CGFloat = .pi / 7

        let left = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        context.saveGState()
        context.setFillColor(color.cgColor)
        context.move(to: end)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }

    private static func drawImages(_ images: [PDFEditorController.InsertedImage], pageRect: CGRect, pageBounds: CGRect, quality: CGFloat) {
        for inserted in images {
            let source = inserted.bounds
            let x = source.minX - pageBounds.minX
            let y = pageBounds.maxY - source.maxY
            let drawRect = CGRect(x: x, y: y, width: source.width, height: source.height)

            if quality < 1.0, !imageHasAlpha(inserted.image) {
                if let compressedData = inserted.image.jpegData(compressionQuality: quality),
                   let compressedImage = UIImage(data: compressedData) {
                    compressedImage.draw(in: drawRect)
                    continue
                }
            }
            inserted.image.draw(in: drawRect)
        }
    }

    private static func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return true }
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    private static func draw(record: PageDrawing, in cgContext: CGContext, pageRect: CGRect, quality: CGFloat) {
        guard record.canvasSize.width.isFinite, record.canvasSize.height.isFinite else { return }
        guard record.canvasSize.width > 1, record.canvasSize.height > 1 else { return }

        let scaleX = pageRect.width / record.canvasSize.width
        let scaleY = pageRect.height / record.canvasSize.height
        guard scaleX.isFinite, scaleY.isFinite else { return }
        guard scaleX > 0.01, scaleY > 0.01 else { return }

        let drawRect = CGRect(origin: .zero, size: record.canvasSize)
        let image = record.drawing.image(from: drawRect, scale: quality > 0.5 ? 2.0 : 1.0)

        cgContext.saveGState()
        cgContext.scaleBy(x: scaleX, y: scaleY)
        UIGraphicsPushContext(cgContext)
        image.draw(in: drawRect)
        UIGraphicsPopContext()
        cgContext.restoreGState()
    }
}
