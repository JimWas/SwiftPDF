import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject private var proManager = ProManager.shared
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedProductID: String?
    @State private var showingPrivacyPolicy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Close")
                    }
                }
        }
            .task { await store.loadProducts() }
            .onAppear { selectDefaultPlan(from: store.products) }
            .onChange(of: store.products) { _, products in selectDefaultPlan(from: products) }
            .onChange(of: proManager.isPro) { _, isPro in if isPro { dismiss() } }
            .onChange(of: store.purchaseState) { _, state in handlePurchaseState(state) }
            .alert("Something Went Wrong", isPresented: showingErrorAlert) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 22) {
                headline
                featureList

                if proManager.isPro {
                    proBadge
                } else if store.products.isEmpty, store.isLoadingProducts {
                    ProgressView("Loading plans…")
                        .padding(.vertical, 12)
                } else if store.products.isEmpty {
                    plansUnavailableView
                } else {
                    planPicker
                }

                if !proManager.isPro {
                    continueButton
                    restoreButton
                }

                legalFooter
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var headline: some View {
        VStack(spacing: 8) {
            Text("SwiftPDF PRO")
                .font(.system(size: 32, weight: .bold))
            Text("Unlock the full potential of your PDFs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "nosign", title: "No Ads", subtitle: "Remove all banners and interstitials.")
            FeatureRow(icon: "text.viewfinder", title: "Unlimited OCR", subtitle: "Extract text from as many pages as you want.")
            FeatureRow(icon: "signature", title: "Unlimited Signatures", subtitle: "Save drawn signatures or names in distinct writing styles.")
            FeatureRow(icon: "lock.shield", title: "Password Protection", subtitle: "Secure your PDFs when you export.")
            FeatureRow(icon: "square.grid.2x2", title: "Advanced Management", subtitle: "Combine and reorder pages without limits.")
            FeatureRow(icon: "wand.and.stars", title: "Premium PDF Tools", subtitle: "Convert images, create Markdown, repair, unlock, and protect PDFs.")
        }
        .padding(.horizontal, 30)
    }

    private var showingErrorAlert: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func selectDefaultPlan(from products: [Product]) {
        guard selectedProductID == nil else { return }
        selectedProductID = products.first { $0.id == StoreManager.annualID }?.id ?? products.first?.id
    }

    private func handlePurchaseState(_ state: StoreManager.PurchaseState) {
        if case .error(let message) = state {
            errorMessage = message
        }
    }

    private var proBadge: some View {
        Label("You're a Pro member", systemImage: "checkmark.seal.fill")
            .font(.headline)
            .foregroundStyle(.orange)
            .padding(.vertical, 8)
    }

    private var plansUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Plans unavailable")
                .font(.headline)

            Text(store.productLoadError ?? "The App Store did not return any Pro plans.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await store.loadProducts(force: true) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoadingProducts)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 30)
    }

    private var planPicker: some View {
        VStack(spacing: 10) {
            if let monthly = store.monthlyProduct {
                PlanCard(
                    product: monthly,
                    badge: nil,
                    isSelected: selectedProductID == monthly.id
                ) { selectedProductID = monthly.id }
            }
            if let annual = store.annualProduct {
                PlanCard(
                    product: annual,
                    badge: annualSavingsBadge,
                    isSelected: selectedProductID == annual.id
                ) { selectedProductID = annual.id }
            }
            if let lifetime = store.lifetimeProduct {
                PlanCard(
                    product: lifetime,
                    badge: "Pay Once",
                    isSelected: selectedProductID == lifetime.id
                ) { selectedProductID = lifetime.id }
            }
        }
        .padding(.horizontal, 30)
    }

    private var annualSavingsBadge: String? {
        guard let monthly = store.monthlyProduct, let annual = store.annualProduct else { return nil }
        let yearlyAtMonthlyRate = monthly.price * 12
        guard yearlyAtMonthlyRate > 0, annual.price < yearlyAtMonthlyRate else { return nil }
        let savings = (1 - (annual.price / yearlyAtMonthlyRate)) * 100
        let percent = NSDecimalNumber(decimal: savings).intValue
        return "Save \(percent)%"
    }

    private var continueButton: some View {
        Button {
            guard let product = store.products.first(where: { $0.id == selectedProductID }) else { return }
            Task { await store.purchase(product) }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(14)
        }
        .disabled(selectedProductID == nil || isPurchasing)
        .padding(.horizontal, 30)
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .disabled(isPurchasing)
    }

    private var isPurchasing: Bool {
        if case .purchasing = store.purchaseState { return true }
        return false
    }

    private var legalFooter: some View {
        VStack(spacing: 4) {
            Text("Subscriptions renew automatically until cancelled. Manage or cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: LegalLinks.appleStandardEULA)
                Button("Privacy Policy") { showingPrivacyPolicy = true }
            }
            .font(.caption2)
        }
        .padding(.bottom, 8)
    }
}

private struct PlanCard: View {
    let product: Product
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
}
