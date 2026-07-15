import SwiftUI
import UniformTypeIdentifiers

enum LocalDocumentTool: String, CaseIterable, Identifiable {
    case compress
    case pdfToWord
    case wordToPDF
    case excelToPDF
    case pdfToJPG
    case jpgToPDF
    case pdfToMarkdown
    case repairPDF
    case unlockPDF
    case protectPDF

    var id: Self { self }

    var title: String {
        switch self {
        case .compress: "Compress PDF"
        case .pdfToWord: "PDF to Word"
        case .wordToPDF: "Word to PDF"
        case .excelToPDF: "Excel to PDF"
        case .pdfToJPG: "PDF to JPG"
        case .jpgToPDF: "JPG to PDF"
        case .pdfToMarkdown: "PDF to Markdown"
        case .repairPDF: "Repair PDF"
        case .unlockPDF: "Unlock PDF"
        case .protectPDF: "Protect PDF"
        }
    }

    var detail: String {
        switch self {
        case .compress: "Reduce file size while keeping pages clear and readable."
        case .pdfToWord: "Create an editable DOCX using embedded text or OCR on your device."
        case .wordToPDF: "Convert DOCX documents into PDFs that are easy to share."
        case .excelToPDF: "Turn XLSX worksheets into paginated PDF tables."
        case .pdfToJPG: "Convert every PDF page to JPG or extract its embedded images."
        case .jpgToPDF: "Combine JPG images into a PDF with your preferred page layout."
        case .pdfToMarkdown: "Turn PDF text into structured Markdown for notes, documentation, and LLMs."
        case .repairPDF: "Rebuild readable pages and recover content from a damaged PDF."
        case .unlockPDF: "Remove password security from a PDF you are authorized to modify."
        case .protectPDF: "Encrypt a PDF with a password to prevent unauthorized access."
        }
    }

    var symbol: String {
        switch self {
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .pdfToWord: "doc.text"
        case .wordToPDF: "doc.richtext"
        case .excelToPDF: "tablecells"
        case .pdfToJPG: "photo.on.rectangle.angled"
        case .jpgToPDF: "doc.badge.plus"
        case .pdfToMarkdown: "text.document"
        case .repairPDF: "cross.case"
        case .unlockPDF: "lock.open"
        case .protectPDF: "lock.shield"
        }
    }

    var color: Color {
        switch self {
        case .compress: .green
        case .pdfToWord: .blue
        case .wordToPDF: .indigo
        case .excelToPDF: .teal
        case .pdfToJPG: .pink
        case .jpgToPDF: .cyan
        case .pdfToMarkdown: .purple
        case .repairPDF: .orange
        case .unlockPDF: .mint
        case .protectPDF: .red
        }
    }

    var inputTypes: [UTType] {
        switch self {
        case .compress, .pdfToWord, .pdfToJPG, .pdfToMarkdown, .repairPDF, .unlockPDF, .protectPDF: [.pdf]
        case .jpgToPDF: [.jpeg]
        case .wordToPDF: [LocalDocumentType.docx, LocalDocumentType.legacyWord]
        case .excelToPDF: [LocalDocumentType.xlsx, LocalDocumentType.legacyExcel]
        }
    }

    var outputType: UTType {
        switch self {
        case .pdfToWord: LocalDocumentType.docx
        case .pdfToJPG: LocalDocumentType.zip
        case .pdfToMarkdown: LocalDocumentType.markdown
        default: .pdf
        }
    }

    var supportedInputLabel: String {
        switch self {
        case .compress, .pdfToWord, .pdfToJPG, .pdfToMarkdown, .repairPDF, .unlockPDF, .protectPDF: "PDF"
        case .jpgToPDF: "JPG Images"
        case .wordToPDF: "DOCX"
        case .excelToPDF: "XLSX"
        }
    }

    var isPremium: Bool {
        switch self {
        case .pdfToJPG, .jpgToPDF, .pdfToMarkdown, .repairPDF, .unlockPDF, .protectPDF: true
        default: false
        }
    }
}

struct DocumentToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var proManager = ProManager.shared
    @State private var showingPaywall = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Convert and optimize files without uploading them.")
                            .font(.title2.bold())
                        Label("All processing stays on this device", systemImage: "lock.shield.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(LocalDocumentTool.allCases) { tool in
                            if tool.isPremium && !proManager.isPro {
                                Button {
                                    showingPaywall = true
                                } label: {
                                    ToolCard(tool: tool)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(value: tool) {
                                    ToolCard(tool: tool)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Office conversion is best effort. Complex layouts, uncommon fonts, macros, charts, formulas, and advanced formatting may be simplified. Modern DOCX and XLSX files are supported; legacy DOC and XLS files must first be resaved in the modern format.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(20)
            }
            .navigationTitle("Document Tools")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LocalDocumentTool.self) { tool in
                DocumentToolOperationView(tool: tool)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}

private struct ToolCard: View {
    let tool: LocalDocumentTool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: tool.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tool.color)

            Text(tool.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(tool.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                if tool.isPremium {
                    Text("PRO")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
    }
}

private struct DocumentToolOperationView: View {
    let tool: LocalDocumentTool

    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var isProcessing = false
    @State private var sourceName = ""
    @State private var outputName = "Converted"
    @State private var result: Data?
    @State private var resultSummary: String?
    @State private var errorMessage: String?
    @State private var compressionQuality: PDFCompressionQuality = .maximum
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var pdfToJPGMode: PDFToJPGMode = .pages
    @State private var jpgExportQuality: JPGExportQuality = .high
    @State private var imagePDFOrientation: ImagePDFOrientation = .portrait
    @State private var imagePDFPageSize: ImagePDFPageSize = .fit
    @State private var imagePDFMargin: ImagePDFMargin = .small

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(tool.color)
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    Text(tool.title)
                        .font(.title.bold())
                    Text(tool.detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if tool == .compress {
                    compressionOptions
                }

                if tool == .unlockPDF || tool == .protectPDF {
                    passwordOptions
                }

                if tool == .pdfToJPG {
                    pdfToJPGOptions
                }

                if tool == .jpgToPDF {
                    jpgToPDFOptions
                }

                privacyCard

                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(processingLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                } else if let resultSummary {
                    resultCard(summary: resultSummary)
                } else {
                    Button {
                        showingImporter = true
                    } label: {
                        Label(chooseButtonTitle, systemImage: "folder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canChooseFile)
                }

                if tool == .pdfToWord || tool == .wordToPDF || tool == .excelToPDF {
                    Text("The output is designed for everyday documents. Review the converted file before relying on precise pagination or formatting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if tool == .repairPDF {
                    Text("Repair recovers pages that Apple’s PDF engines can still read. It cannot reconstruct content that is completely missing or irreversibly corrupted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if tool == .unlockPDF {
                    Text("Only remove security from documents you own or have permission to modify.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .navigationTitle(tool.title)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: tool.inputTypes,
            allowsMultipleSelection: tool == .jpgToPDF
        ) { selection in
            handleSelection(selection)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: result.map(ConvertedFileDocument.init),
            contentType: tool.outputType,
            defaultFilename: outputName
        ) { exportResult in
            if case .failure(let error) = exportResult {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Tool Failed", isPresented: errorPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var pdfToJPGOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion")
                .font(.headline)

            Picker("Conversion mode", selection: $pdfToJPGMode) {
                ForEach(PDFToJPGMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(pdfToJPGMode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Image quality", selection: $jpgExportQuality) {
                ForEach(JPGExportQuality.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var jpgToPDFOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Page Layout")
                .font(.headline)

            Text("Orientation")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Orientation", selection: $imagePDFOrientation) {
                ForEach(ImagePDFOrientation.allCases) { orientation in
                    Text(orientation.rawValue).tag(orientation)
                }
            }
            .pickerStyle(.segmented)

            Text("Page Size")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Page size", selection: $imagePDFPageSize) {
                ForEach(ImagePDFPageSize.allCases) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)

            Text("Margin")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Margin", selection: $imagePDFMargin) {
                ForEach(ImagePDFMargin.allCases) { margin in
                    Text(margin.rawValue).tag(margin)
                }
            }
            .pickerStyle(.segmented)

            Text("Select multiple JPG images to combine them into one PDF in the order provided by Files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var passwordOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tool == .protectPDF ? "Create Password" : "Current PDF Password")
                .font(.headline)

            SecureField(tool == .protectPDF ? "New password" : "Password", text: $password)
                .textContentType(tool == .protectPDF ? .newPassword : .password)
                .padding(12)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            if tool == .protectPDF {
                SecureField("Confirm password", text: $passwordConfirmation)
                    .textContentType(.newPassword)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                Text("Use at least six characters. SwiftPDF does not store or recover passwords.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !passwordConfirmation.isEmpty, password != passwordConfirmation {
                    Label("Passwords do not match", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text("The password is used only in memory and cleared when processing finishes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var compressionOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compression")
                .font(.headline)
            Picker("Compression quality", selection: $compressionQuality) {
                ForEach(PDFCompressionQuality.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            Text(compressionQuality.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Compression preserves the page appearance but flattens interactive forms, links, annotations, and selectable text. Keep the original if you may need to edit those elements later.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "iphone.and.arrow.forward")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Processed on this iPhone")
                    .font(.subheadline.bold())
                Text("The selected file is not uploaded or sent to SwiftPDF, an AI service, or another company.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultCard(summary: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.green)
            Text(summary)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button {
                showingExporter = true
            } label: {
                Label("Save Converted File", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Button("Convert Another File") {
                result = nil
                resultSummary = nil
                sourceName = ""
                password = ""
                passwordConfirmation = ""
                if tool != .unlockPDF && tool != .protectPDF {
                    showingImporter = true
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var processingLabel: String {
        switch tool {
        case .compress: "Optimizing PDF pages…"
        case .pdfToWord: "Extracting editable text on your device…"
        case .wordToPDF, .excelToPDF: "Rendering document on your device…"
        case .pdfToJPG: "Creating JPG images on your device…"
        case .jpgToPDF: "Building PDF pages on your device…"
        case .pdfToMarkdown: "Structuring Markdown on your device…"
        case .repairPDF: "Recovering readable PDF pages…"
        case .unlockPDF: "Removing PDF security on your device…"
        case .protectPDF: "Encrypting PDF on your device…"
        }
    }

    private var chooseButtonTitle: String {
        tool == .jpgToPDF ? "Choose JPG Images" : "Choose \(tool.supportedInputLabel) File"
    }

    private var canChooseFile: Bool {
        switch tool {
        case .unlockPDF: !password.isEmpty
        case .protectPDF: password.count >= 6 && password == passwordConfirmation
        default: true
        }
    }

    private func handleSelection(_ selection: Result<[URL], Error>) {
        guard case .success(let urls) = selection, let url = urls.first else {
            if case .failure(let error) = selection { errorMessage = error.localizedDescription }
            return
        }
        sourceName = url.deletingPathExtension().lastPathComponent
        isProcessing = true
        result = nil
        resultSummary = nil

        Task {
            defer {
                if tool == .unlockPDF || tool == .protectPDF {
                    password = ""
                    passwordConfirmation = ""
                }
            }
            do {
                let data = try readSecurityScopedFile(url)
                switch tool {
                case .compress:
                    let compressed = try PDFCompressionService.compress(data: data, quality: compressionQuality)
                    result = compressed.data
                    outputName = "\(sourceName)-compressed.pdf"
                    if compressed.usedOriginal {
                        resultSummary = "This PDF was already efficiently optimized, so SwiftPDF preserved the original quality and file size."
                    } else {
                        let percentage = Int((compressed.savedFraction * 100).rounded())
                        resultSummary = "Reduced the file from \(formattedBytes(compressed.originalBytes)) to \(formattedBytes(compressed.compressedBytes)). The result is \(percentage)% smaller."
                    }
                case .pdfToWord:
                    result = try await PDFToWordService.convert(data: data)
                    outputName = "\(sourceName).docx"
                    resultSummary = "Your editable Word document is ready."
                case .wordToPDF:
                    result = try OfficeToPDFService.convertWord(data: data, fileExtension: url.pathExtension)
                    outputName = "\(sourceName).pdf"
                    resultSummary = "Your Word document has been converted to PDF."
                case .excelToPDF:
                    result = try OfficeToPDFService.convertExcel(data: data, fileExtension: url.pathExtension)
                    outputName = "\(sourceName).pdf"
                    resultSummary = "Your workbook has been converted to PDF."
                case .pdfToJPG:
                    let conversion = try PDFToJPGService.convert(
                        data: data,
                        mode: pdfToJPGMode,
                        quality: jpgExportQuality
                    )
                    result = conversion.archive
                    outputName = "\(sourceName)-JPG.zip"
                    resultSummary = "Created \(conversion.imageCount) JPG image\(conversion.imageCount == 1 ? "" : "s"). The images are ready in a ZIP file."
                case .jpgToPDF:
                    let imageData = try urls.map(readSecurityScopedFile)
                    result = try JPGToPDFService.convert(
                        imageData: imageData,
                        orientation: imagePDFOrientation,
                        pageSize: imagePDFPageSize,
                        margin: imagePDFMargin
                    )
                    outputName = urls.count == 1 ? "\(sourceName).pdf" : "Combined Images.pdf"
                    resultSummary = "Created a PDF containing \(urls.count) image\(urls.count == 1 ? "" : "s")."
                case .pdfToMarkdown:
                    result = try await PDFMarkdownService.convert(data: data)
                    outputName = "\(sourceName).md"
                    resultSummary = "Your Markdown file is ready. Review complex tables and headings for best results."
                case .repairPDF:
                    let repaired = try PDFRepairService.repair(data: data)
                    result = repaired.data
                    outputName = "\(sourceName)-repaired.pdf"
                    resultSummary = "Recovered \(repaired.recoveredPages) readable page\(repaired.recoveredPages == 1 ? "" : "s") into a clean PDF."
                case .unlockPDF:
                    result = try PDFSecurityService.unlock(data: data, password: password).data
                    outputName = "\(sourceName)-unlocked.pdf"
                    resultSummary = "Password security was removed from the PDF."
                case .protectPDF:
                    result = try PDFSecurityService.protect(data: data, password: password)
                    outputName = "\(sourceName)-protected.pdf"
                    resultSummary = "The PDF is now encrypted with your password. Store the password somewhere safe."
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func readSecurityScopedFile(_ url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

    private func formattedBytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    DocumentToolsView()
}
