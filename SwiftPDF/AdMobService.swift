//
//  AdMobService.swift
//  SwiftPDF
//
//  Created by Codex on 2/22/26.
//

import SwiftUI
import Combine

#if canImport(GoogleMobileAds) && os(iOS)
import GoogleMobileAds
import UIKit
#endif

@MainActor
final class AdMobService: NSObject, ObservableObject {
    #if canImport(GoogleMobileAds) && os(iOS)
    @Published private(set) var nativeAd: GADNativeAd?

    private let interstitialAdUnitID = "ca-app-pub-3057383894764696/4154468313"
    private let nativeAdUnitID = "ca-app-pub-3057383894764696/2728513064"
    private let rewardedAdUnitID = "ca-app-pub-3057383894764696/7406124676"
    private let interstitialInterval = 3

    private var adLoader: GADAdLoader?
    private var interstitialAd: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    private var completedActions = 0
    private var pendingActionAfterAd: (() -> Void)?
    private var configured = false
    private var hasHandledFirstSave = false
    #endif

    func configure() {
        #if canImport(GoogleMobileAds) && os(iOS)
        guard !configured else { return }
        configured = true
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        loadNativeAd()
        loadInterstitial()
        loadRewarded()
        #endif
    }

    var hasNativeAd: Bool {
        #if canImport(GoogleMobileAds) && os(iOS)
        return nativeAd != nil
        #else
        return false
        #endif
    }

    func maybePresentInterstitial(after action: @escaping () -> Void) {
        #if canImport(GoogleMobileAds) && os(iOS)
        if ProManager.shared.isPro {
            action()
            return
        }
        presentInterstitialIfEligible(after: action)
        #else
        action()
        #endif
    }

    func maybePresentSaveAd(after action: @escaping () -> Void) {
        #if canImport(GoogleMobileAds) && os(iOS)
        if ProManager.shared.isPro {
            action()
            return
        }
        if !hasHandledFirstSave {
            hasHandledFirstSave = true
            guard let ad = rewardedAd, let root = topViewController() else {
                action()
                loadRewarded()
                return
            }
            pendingActionAfterAd = action
            rewardedAd = nil
            ad.fullScreenContentDelegate = self
            ad.present(fromRootViewController: root) {
                _ = ad.adReward
            }
            return
        }
        presentInterstitialIfEligible(after: action)
        #else
        action()
        #endif
    }

    private func presentInterstitialIfEligible(after action: @escaping () -> Void) {
        completedActions += 1
        guard completedActions % interstitialInterval == 0 else {
            action()
            return
        }
        guard let ad = interstitialAd else {
            action()
            loadInterstitial()
            return
        }
        guard let root = topViewController() else {
            action()
            return
        }
        pendingActionAfterAd = action
        interstitialAd = nil
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: root)
    }
}

struct AdMobNativeCard: View {
    @EnvironmentObject private var adService: AdMobService

    var body: some View {
        #if canImport(GoogleMobileAds) && os(iOS)
        if !ProManager.shared.isPro, let nativeAd = adService.nativeAd {
            HomeNativeAdCard(nativeAd: nativeAd)
                .frame(maxWidth: 520)
                .frame(height: 104)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds) && os(iOS)
extension AdMobService {
    fileprivate func loadNativeAd() {
        adLoader = GADAdLoader(
            adUnitID: nativeAdUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(GADRequest())
    }

    fileprivate func loadInterstitial() {
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: GADRequest()) { [weak self] ad, _ in
            Task { @MainActor [weak self] in
                self?.interstitialAd = ad
            }
        }
    }

    fileprivate func loadRewarded() {
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: GADRequest()) { [weak self] ad, _ in
            Task { @MainActor [weak self] in
                self?.rewardedAd = ad
            }
        }
    }

    fileprivate func runPendingActionIfNeeded() {
        let action = pendingActionAfterAd
        pendingActionAfterAd = nil
        action?()
    }

    fileprivate func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension AdMobService: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.loadInterstitial()
            self.loadRewarded()
            self.runPendingActionIfNeeded()
        }
    }

    nonisolated func ad(
        _ ad: any GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.loadInterstitial()
            self.loadRewarded()
            self.runPendingActionIfNeeded()
        }
    }
}

extension AdMobService: GADNativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        Task { @MainActor [weak self] in
            self?.nativeAd = nativeAd
        }
    }

    nonisolated func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: any Error) {
        Task { @MainActor [weak self] in
            self?.nativeAd = nil
        }
    }
}

struct HomeNativeAdCard: UIViewRepresentable {
    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> NativeAdCardView {
        NativeAdCardView()
    }

    func updateUIView(_ uiView: NativeAdCardView, context: Context) {
        uiView.apply(nativeAd: nativeAd)
    }
}

final class NativeAdCardView: GADNativeAdView {
    private let adBadge = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let callToActionButton = UIButton(type: .system)
    private let iconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func apply(nativeAd: GADNativeAd) {
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = nativeAd.body == nil

        callToActionButton.setTitle(nativeAd.callToAction, for: .normal)
        callToActionButton.isHidden = nativeAd.callToAction == nil
        callToActionButton.isUserInteractionEnabled = false

        iconImageView.image = nativeAd.icon?.image
        iconImageView.isHidden = nativeAd.icon?.image == nil

        self.nativeAd = nativeAd
    }

    private func setup() {
        backgroundColor = UIColor.secondarySystemBackground
        layer.cornerRadius = 14
        layer.masksToBounds = true

        adBadge.text = "Ad"
        adBadge.font = .systemFont(ofSize: 11, weight: .semibold)
        adBadge.textColor = .secondaryLabel

        headlineLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        headlineLabel.textColor = .label
        headlineLabel.numberOfLines = 2

        bodyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2

        callToActionButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.baseBackgroundColor = .systemBlue
        buttonConfig.baseForegroundColor = .white
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        buttonConfig.cornerStyle = .medium
        callToActionButton.configuration = buttonConfig

        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 10
        iconImageView.clipsToBounds = true
        iconImageView.backgroundColor = .tertiarySystemFill

        let textStack = UIStackView(arrangedSubviews: [adBadge, headlineLabel, bodyLabel, callToActionButton])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading

        let rootStack = UIStackView(arrangedSubviews: [iconImageView, textStack])
        rootStack.axis = .horizontal
        rootStack.spacing = 12
        rootStack.alignment = .center
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),
        ])

        headlineView = headlineLabel
        bodyView = bodyLabel
        callToActionView = callToActionButton
        iconView = iconImageView
    }
}
#endif
