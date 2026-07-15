import Combine
import Foundation
import SwiftUI

/// Thin facade over `StoreManager` so the rest of the app can keep reading
/// `ProManager.shared.isPro` without knowing about StoreKit. `isPro` is mirrored
/// from `StoreManager`'s verified entitlements; the UserDefaults cache only
/// exists so the UI has a value to show before the first StoreKit round trip
/// finishes at launch.
@MainActor
final class ProManager: ObservableObject {
    @Published private(set) var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "SwiftPDF_IsPro")
        }
    }

    // For trial/limiting free users
    @Published var ocrUsageCount: Int {
        didSet {
            UserDefaults.standard.set(ocrUsageCount, forKey: "SwiftPDF_OCRCount")
        }
    }

    static let shared = ProManager()

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.isPro = UserDefaults.standard.bool(forKey: "SwiftPDF_IsPro")
        self.ocrUsageCount = UserDefaults.standard.integer(forKey: "SwiftPDF_OCRCount")

        StoreManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPro in
                self?.isPro = isPro
            }
            .store(in: &cancellables)
    }

    #if DEBUG
    /// Simulator/QA-only free unlock. Compiled out of release/App Store builds.
    func togglePro() {
        isPro.toggle()
    }
    #endif

    func canPerformOCR() -> Bool {
        if isPro { return true }
        return ocrUsageCount < 3
    }

    func incrementOCRUsage() {
        if !isPro {
            ocrUsageCount += 1
        }
    }

    func resetOCRUsage() {
        // You could call this daily via a background task
        ocrUsageCount = 0
    }
}
