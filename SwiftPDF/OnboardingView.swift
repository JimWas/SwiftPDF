import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages = OnboardingPage.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip Tutorial", action: onFinish)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 44)
                .padding(.horizontal, 24)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        OnboardingPageView(page: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: page)

                Button {
                    if page == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Start Using SwiftPDF" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .background(Color(.systemBackground))
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            Image(systemName: page.symbol)
                .font(.system(size: 72, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(page.color)
                .frame(height: 100)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(page.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 480)
            }
            .padding(.horizontal, 32)

            if !page.tips.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.tips, id: \.self) { tip in
                        Label(tip, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.primary)
                    }
                }
                .font(.subheadline)
                .padding(20)
                .frame(maxWidth: 480, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 28)
            }

            Spacer()
        }
    }
}

private struct OnboardingPage {
    let symbol: String
    let color: Color
    let title: String
    let detail: String
    let tips: [String]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: "doc.text.fill",
            color: .accentColor,
            title: "Welcome to SwiftPDF",
            detail: "Everything you need to work with PDFs on your iPhone, without uploading your documents to a server.",
            tips: ["Edit locally on your device", "No account or sign in required"]
        ),
        OnboardingPage(
            symbol: "pencil.and.outline",
            color: .blue,
            title: "Open and Edit",
            detail: "Tap Open PDF, choose a document from Files, then use the editor toolbar to draw, add text, correct existing text or dates, insert images, and manage pages.",
            tips: ["Open Text Tools and choose Correct Text or Date", "Use Identify Font to match the original style", "Save or share when you are finished"]
        ),
        OnboardingPage(
            symbol: "signature",
            color: .purple,
            title: "Sign Documents",
            detail: "Open the signature library, then draw a signature or type a signer name and choose a writing style. Tap a saved signature whenever you want to place it on a PDF.",
            tips: ["Choose a different style for each signer", "Pro supports unlimited saved signatures"]
        ),
        OnboardingPage(
            symbol: "doc.viewfinder",
            color: .orange,
            title: "Scan, Convert, and Optimize",
            detail: "Scan paper, combine PDFs, compress large files, convert PDF to editable DOCX, or convert Word, Excel, and JPG files.",
            tips: ["Pro adds JPG conversion, Markdown, repair, unlock, and protect tools", "Conversion and OCR stay on your device"]
        ),
        OnboardingPage(
            symbol: "lock.shield.fill",
            color: .green,
            title: "Your Files, Your Privacy",
            detail: "SwiftPDF stores shortcuts to recent files for convenience, never the contents on a developer server. You can clear recents anytime from Home or Settings.",
            tips: ["Clearing recents does not delete your PDFs", "Replay this tutorial from Settings"]
        )
    ]
}

#Preview {
    OnboardingView(onFinish: {})
}
