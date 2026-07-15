//
//  LegalDocumentView.swift
//  SwiftPDF
//

import SwiftUI

/// Apple provides a standard EULA that satisfies App Store Review Guideline 3.1.2's
/// requirement for a Terms of Use link, so SwiftPDF links to it directly instead of
/// hosting a custom one. See https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
enum LegalLinks {
    static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// In-app Privacy Policy. The same copy should also be published at a public URL
/// (e.g. GitHub Pages) so it can be entered in App Store Connect's Privacy Policy field.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Last updated: \(Self.lastUpdated)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    section(
                        title: "Overview",
                        body: "SwiftPDF is designed to work entirely on your device. We do not operate a server, require an account, or see the contents of your documents. This policy explains what limited data the app stores and why."
                    )

                    section(
                        title: "Documents You Open",
                        body: "PDFs you open, scan, or edit stay on your device (or in the iCloud/Files location you chose). SwiftPDF keeps a secure reference to your most recent files so you can reopen them quickly; it does not upload document contents anywhere."
                    )

                    section(
                        title: "Local Text Recognition",
                        body: "Text extraction (OCR) uses Apple's Vision framework on your device. Scanned pages are analyzed locally and are never sent to SwiftPDF or any third party for this feature."
                    )

                    section(
                        title: "Compression & File Conversion",
                        body: "PDF compression, image conversion, Markdown conversion, repair, password security, and PDF, JPG, DOCX, and XLSX conversion are performed entirely on your device. Selected documents and passwords are not uploaded to SwiftPDF, an AI service, or another company. Temporary conversion files are removed after processing, and passwords are not stored."
                    )

                    section(
                        title: "Signatures & Autofill Profile",
                        body: "Saved signatures and the optional Autofill Profile (name, email, phone, address) are stored locally using iOS's standard storage. This data is used only to fill in your documents and is never transmitted to SwiftPDF's developer."
                    )

                    section(
                        title: "Camera",
                        body: "Camera access is used only for the included document scanner to capture pages you choose to scan. Images are processed on your device."
                    )

                    section(
                        title: "Advertising",
                        body: "People using the free version may see ads served through Google AdMob. With your permission (via Apple's App Tracking Transparency prompt), AdMob may use your device's advertising identifier to show more relevant ads. You can decline tracking at any time in Settings > Privacy > Tracking, or remove ads entirely by upgrading to Pro. Google's use of this data is governed by Google's own privacy policy."
                    )

                    section(
                        title: "Purchases",
                        body: "Subscriptions and lifetime purchases are processed entirely by Apple through the App Store. SwiftPDF never sees or stores your payment information."
                    )

                    section(
                        title: "Your Choices",
                        body: "You can delete locally stored signatures and your Autofill Profile at any time from within the app. Deleting the app removes this locally stored data."
                    )

                    section(
                        title: "Contact",
                        body: "Questions about this policy can be sent to the developer via the contact details listed on SwiftPDF's App Store page."
                    )
                }
                .padding(24)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static let lastUpdated: String = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }()

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
