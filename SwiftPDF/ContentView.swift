//
//  ContentView.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers
#if canImport(VisionKit) && os(iOS)
import VisionKit
#endif

struct ContentView: View {
    @EnvironmentObject private var adService: AdMobService
    @AppStorage("swiftpdf.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var recentStore = RecentStore()
    @StateObject private var editorController = PDFEditorController()
    @ObservedObject private var proManager = ProManager.shared
    @State private var showingImporter = false
    @State private var showingMultiImporter = false
    @State private var showingEditor = false
    @State private var showingScanner = false
    @State private var showingPaywall = false
    @State private var showingSettings = false
    @State private var showingDocumentTools = false
    @State private var showingOnboarding = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            HomeView(
                recents: recentStore.recents,
                showNativeAd: adService.hasNativeAd,
                isPro: proManager.isPro,
                openAction: { showingImporter = true },
                scanAction: { startScan() },
                mergeAction: { showingMultiImporter = true },
                upgradeAction: { showingPaywall = true },
                settingsAction: { showingSettings = true },
                toolsAction: { showingDocumentTools = true },
                clearRecentsAction: { recentStore.clear() },
                favoriteRecentAction: { recent in recentStore.toggleFavorite(recent) },
                scanEnabled: scanAvailable,
                openRecent: { recent in openRecent(recent) }
            )
            .sheet(isPresented: $showingImporter) {
                OpenPDFPicker { result in
                    showingImporter = false
                    switch result {
                    case .success(let url):
                        openPDF(url: url)
                    case .failure(let error):
                        showError(message: error.localizedDescription)
                    }
                }
            }
            .sheet(isPresented: $showingMultiImporter) {
                MultiPDFPicker { result in
                    showingMultiImporter = false
                    switch result {
                    case .success(let urls):
                        mergePDFs(urls: urls)
                    case .failure(let error):
                        showError(message: error.localizedDescription)
                    }
                }
            }
            #if canImport(VisionKit) && os(iOS)
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView { result in
                    switch result {
                    case .success(let document):
                        openScanned(document)
                    case .failure(let error):
                        showError(message: error.localizedDescription)
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    recentStore: recentStore,
                    signatureStore: editorController.signatureStore
                )
            }
            .sheet(isPresented: $showingDocumentTools) {
                DocumentToolsView()
            }
            .alert("Could not open PDF", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showingEditor) {
                NavigationStack {
                    EditorView(controller: editorController) {
                        editorController.reset()
                        showingEditor = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                    showingOnboarding = false
                }
            }
            .onAppear {
                if !hasCompletedOnboarding {
                    showingOnboarding = true
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    private func openRecent(_ recent: RecentPDF) {
        openPDF(url: recent.url)
    }

    private func mergePDFs(urls: [URL]) {
        guard !urls.isEmpty else { return }
        if urls.count == 1 {
            openPDF(url: urls[0])
            return
        }

        guard let mergedDoc = PDFMergeService.merge(urls: urls) else {
            showError(message: "The PDFs could not be merged.")
            return
        }

        let name = "Merged-\(Int(Date().timeIntervalSince1970)).pdf"
        editorController.load(document: mergedDoc, fileName: name, sourceURL: nil)
        showingEditor = true
    }

    private func openPDF(url: URL) {
        guard let data = loadPDFData(url: url) else {
            showError(message: "The file could not be read.")
            return
        }
        guard let document = PDFDocument(data: data) else {
            showError(message: "The PDF appears to be invalid.")
            return
        }

        editorController.load(document: document, fileName: url.lastPathComponent, sourceURL: url)
        recentStore.add(url: url)
        showingEditor = true
    }

    private func startScan() {
        #if canImport(VisionKit) && os(iOS)
        if VNDocumentCameraViewController.isSupported {
            showingScanner = true
        } else {
            showError(message: ScanError.notSupported.localizedDescription)
        }
        #else
        showError(message: ScanError.notSupported.localizedDescription)
        #endif
    }

    private func openScanned(_ document: PDFDocument) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let name = "Scan-\(formatter.string(from: Date())).pdf"
        editorController.load(document: document, fileName: name, sourceURL: nil)
        showingEditor = true
    }

    private var scanAvailable: Bool {
        #if canImport(VisionKit) && os(iOS)
        return VNDocumentCameraViewController.isSupported
        #else
        return false
        #endif
    }

    private func handleIncomingURL(_ url: URL) {
        guard isPDFFile(url) else { return }
        showingImporter = false
        showingScanner = false
        openPDF(url: url)
    }

    private func isPDFFile(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           contentType.conforms(to: .pdf) {
            return true
        }
        if let type = UTType(filenameExtension: url.pathExtension.lowercased()),
           type.conforms(to: .pdf) {
            return true
        }
        return url.pathExtension.lowercased() == "pdf"
    }

    private func loadPDFData(url: URL) -> Data? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return try? Data(contentsOf: url)
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

private struct HomeView: View {
    let recents: [RecentPDF]
    let showNativeAd: Bool
    let isPro: Bool
    let openAction: () -> Void
    let scanAction: () -> Void
    let mergeAction: () -> Void
    let upgradeAction: () -> Void
    let settingsAction: () -> Void
    let toolsAction: () -> Void
    let clearRecentsAction: () -> Void
    let favoriteRecentAction: (RecentPDF) -> Void
    let scanEnabled: Bool
    let openRecent: (RecentPDF) -> Void
    @State private var confirmingClearRecents = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Button(action: settingsAction) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                    .accessibilityLabel("Settings")

                    Spacer()
                    Button(action: upgradeAction) {
                        Text(isPro ? "PRO" : "GO PRO")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isPro ? Color.orange : Color.accentColor)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 10) {
                    Text("SwiftPDF")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Sign, edit, save, and share in seconds.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Button(action: openAction) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Open PDF")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentColor)
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        )
                    }

                    Button(action: mergeAction) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.square.on.square")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Merge PDFs")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                        )
                    }

                    Button(action: toolsAction) {
                        HStack(spacing: 10) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Document Tools")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.vertical, 14)
                        .frame(maxWidth: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentColor.opacity(0.09))
                        )
                    }
                }

                Button(action: scanAction) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Scan Document")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
                }
                .disabled(!scanEnabled)
                .opacity(scanEnabled ? 1.0 : 0.4)

                if showNativeAd && !isPro {
                    AdMobNativeCard()
                }

                if !recents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent PDFs")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Clear", role: .destructive) {
                                confirmingClearRecents = true
                            }
                                .font(.system(size: 13, weight: .semibold))
                        }

                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(recents) { recent in
                                    RecentRow(
                                        recent: recent,
                                        openAction: { openRecent(recent) },
                                        favoriteAction: { favoriteRecentAction(recent) }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 240)
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
        .confirmationDialog(
            "Clear recent PDF history?",
            isPresented: $confirmingClearRecents,
            titleVisibility: .visible
        ) {
            Button("Clear Recent PDFs", role: .destructive, action: clearRecentsAction)
        } message: {
            Text("This removes shortcuts from SwiftPDF. It does not delete or modify your PDF files.")
        }
    }
}

private struct RecentRow: View {
    let recent: RecentPDF
    let openAction: () -> Void
    let favoriteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: openAction) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recent.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(recent.modifiedLabel)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: favoriteAction) {
                Image(systemName: recent.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(recent.isFavorite ? Color.orange : Color.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recent.isFavorite ? "Remove from Favorites" : "Add to Favorites")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
