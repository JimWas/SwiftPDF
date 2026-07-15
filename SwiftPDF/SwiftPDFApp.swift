//
//  SwiftPDFApp.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import SwiftUI
#if canImport(AppTrackingTransparency) && os(iOS)
import AppTrackingTransparency
#endif

@main
struct SwiftPDFApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var adService = AdMobService()
    @State private var isContentReady = false
    @State private var isPreparingAdvertising = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isContentReady {
                    ContentView()
                        .environmentObject(adService)
                } else {
                    LaunchPreparationView()
                }
            }
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await prepareAdvertisingAndShowContent() }
            }
        }
    }

    @MainActor
    private func prepareAdvertisingAndShowContent() async {
        guard !isContentReady, !isPreparingAdvertising else { return }
        isPreparingAdvertising = true
        defer { isPreparingAdvertising = false }

        try? await Task.sleep(nanoseconds: 500_000_000)
        guard scenePhase == .active else { return }

        await requestTrackingPermissionIfNeeded()
        adService.configure()
        isContentReady = true
    }

    private func requestTrackingPermissionIfNeeded() async {
        #if canImport(AppTrackingTransparency) && os(iOS)
        guard #available(iOS 14, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        #endif
    }
}

private struct LaunchPreparationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            ProgressView()
                .accessibilityLabel("Preparing SwiftPDF")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
