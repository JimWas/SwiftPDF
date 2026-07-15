import StoreKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var recentStore: RecentStore
    @ObservedObject var signatureStore: SignatureStore
    @ObservedObject private var proManager = ProManager.shared
    @ObservedObject private var store = StoreManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared

    @Environment(\.dismiss) private var dismiss
    @State private var showingPaywall = false
    @State private var showingTutorial = false
    @State private var showingPrivacyPolicy = false
    @State private var confirmingClearRecents = false
    @State private var confirmingClearSignatures = false
    @State private var confirmingClearProfile = false
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                proSection
                helpSection
                privacySection
                legalSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
            .fullScreenCover(isPresented: $showingTutorial) {
                OnboardingView { showingTutorial = false }
            }
            .confirmationDialog(
                "Clear recent PDF history?",
                isPresented: $confirmingClearRecents,
                titleVisibility: .visible
            ) {
                Button("Clear Recent PDFs", role: .destructive) { recentStore.clear() }
            } message: {
                Text("This removes file shortcuts from SwiftPDF. It does not delete or modify your PDF files.")
            }
            .confirmationDialog(
                "Delete all saved signatures?",
                isPresented: $confirmingClearSignatures,
                titleVisibility: .visible
            ) {
                Button("Delete Saved Signatures", role: .destructive) { signatureStore.clear() }
            } message: {
                Text("This cannot be undone. Signatures already placed in exported PDFs are not affected.")
            }
            .confirmationDialog(
                "Clear the autofill profile?",
                isPresented: $confirmingClearProfile,
                titleVisibility: .visible
            ) {
                Button("Clear Autofill Profile", role: .destructive) { profileStore.clear() }
            } message: {
                Text("This deletes the name, email, phone number, and address stored locally by SwiftPDF.")
            }
            .alert("Restore Purchases", isPresented: restoreAlertPresented) {
                Button("OK", role: .cancel) { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    private var proSection: some View {
        Section("SwiftPDF Pro") {
            LabeledContent("Status", value: proManager.isPro ? "Active" : "Free")

            if !proManager.isPro {
                Button {
                    showingPaywall = true
                } label: {
                    Label("View Pro Options", systemImage: "sparkles")
                }
            }

            Button {
                Task {
                    await store.restorePurchases()
                    restoreMessage = proManager.isPro
                        ? "Your SwiftPDF Pro purchase has been restored."
                        : "No previous SwiftPDF Pro purchase was found for this Apple ID."
                }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            .disabled(isRestoring)

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                Label("Manage Subscriptions", systemImage: "creditcard")
            }

            Text("Pro removes ads and unlocks unlimited OCR, unlimited saved signatures, password protection, JPG conversion, PDF to Markdown, repair, unlock, and advanced document tools.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var helpSection: some View {
        Section("Help") {
            Button {
                showingTutorial = true
            } label: {
                Label("Replay Getting Started Tutorial", systemImage: "questionmark.circle")
            }

            NavigationLink {
                ProfileEditorView()
            } label: {
                Label("Autofill Profile", systemImage: "person.text.rectangle")
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy & Local Data") {
            Button(role: .destructive) {
                confirmingClearRecents = true
            } label: {
                Label("Clear Recent PDFs", systemImage: "clock.arrow.circlepath")
            }
            .disabled(recentStore.recents.isEmpty)

            Button(role: .destructive) {
                confirmingClearSignatures = true
            } label: {
                Label("Delete Saved Signatures", systemImage: "signature")
            }
            .disabled(signatureStore.signatures.isEmpty)

            Button(role: .destructive) {
                confirmingClearProfile = true
            } label: {
                Label("Clear Autofill Profile", systemImage: "person.crop.circle.badge.xmark")
            }

            Text("These controls remove data stored locally by SwiftPDF. Your PDF files remain in Files or iCloud Drive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: LegalLinks.appleStandardEULA) {
                Label("Terms of Use", systemImage: "doc.text")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: versionLabel)
            Label("Documents, conversion, and OCR are processed on your device", systemImage: "iphone")
                .font(.subheadline)
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var isRestoring: Bool {
        if case .purchasing("restore") = store.purchaseState { return true }
        return false
    }

    private var restoreAlertPresented: Binding<Bool> {
        Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )
    }
}

#Preview {
    SettingsView(recentStore: RecentStore(), signatureStore: SignatureStore())
}
