# Changelog

All notable changes to SwiftPDF are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/spec/v2.0.0.html) where practical.

## [Unreleased]

### Added

- Typed PDF signatures with Classic, Elegant, Casual, Flourish, Bold, and Modern writing styles.
- Live signature previews that let separate signers select visibly different styles.
- Text and date correction mode with automatic word detection for selectable PDFs.
- Movable and resizable correction boxes for scanned or flattened PDFs.
- Common document fonts including Helvetica, Arial, Times New Roman, Georgia, Avenir Next, Futura, and Courier.
- Custom correction background colors for matching nonwhite PDF pages.
- On device font identification using embedded PDF metadata or OCR based visual matching for scans.

### Changed

- Saved signature storage now supports both typed signatures and existing PencilKit drawings.
- Text and date correction and font identification now require Pro. Basic Add Text remains available without Pro.
- Consolidated editor overflow controls into one labeled Editor Menu with a clearly named Text Tools submenu.
- Added visible labels to Signature, Shapes, Save PDF, Share PDF, Draw, and Finish Drawing controls.
- Restored pinch zoom and page panning with an eight times magnification range.
- Added Zoom In, Zoom Out, Fit Page, and Hide Canvas Controls commands to the Editor Menu.
- Added a persistent floating Close Text Tool button for Add Text, Correct Text or Date, and Identify Font modes.

### Fixed

### Security

## [1.0.0] - 2026-07-15

Initial App Store release candidate.

### Added

- PDF opening from Files and iCloud Drive.
- VisionKit document scanning.
- PDF merging and page extraction.
- PencilKit drawing with pen, highlighter, and eraser tools.
- Text annotations with font, size, color, bold, italic, and strikethrough controls.
- Shape annotations including rectangles, circles, lines, and arrows.
- Image insertion and movable image overlays.
- Reusable signatures created with PencilKit.
- One free saved signature and unlimited saved signatures with Pro.
- Page reordering, rotation, deletion, extraction, and bulk management.
- Current page and full document export options.
- Original file overwrite and Save As support.
- Password protected PDF export for Pro users.
- Batch watermarking for Pro users.
- Autofill profile and smart PDF form filling.
- Vision based OCR with three free uses and unlimited Pro access.
- Recent PDF history using security scoped bookmarks.
- Favorite recent PDFs that remain at the top for quick access.
- Clear Recent PDFs controls on Home and in Settings.
- First launch onboarding with Skip Tutorial and replay support.
- Settings for purchases, tutorial replay, privacy controls, legal information, and local data removal.
- StoreKit 2 monthly, annual, and lifetime Pro products.
- Verified entitlement handling and purchase restoration.
- Local StoreKit configuration for simulator and development testing.
- Adaptive Pro paywall with live App Store product names, descriptions, and prices.
- Apple standard EULA and privacy policy access from the paywall.
- Native, interstitial, and rewarded Google Mobile Ads support for free users.
- App Tracking Transparency request before advertising initialization.
- Local PDF compression with three quality modes.
- Local PDF to DOCX conversion with OCR fallback.
- Local DOCX to PDF and XLSX to PDF conversion.
- Pro PDF to Markdown conversion.
- Pro PDF repair.
- Pro PDF unlock and password protection tools.
- Pro PDF to JPG page conversion with Normal and High quality options.
- Pro extraction of embedded PDF images.
- ZIP export for generated JPG images.
- Pro JPG to PDF conversion for one or multiple images.
- Portrait and landscape JPG to PDF layouts.
- Fit, A4, and Letter page sizes.
- None, Small, and Large margin options.
- Local privacy policy covering document processing, signatures, profile data, advertising, and purchases.
- Complete app icons including light, dark, and tinted variants.

### Changed

- Replaced placeholder premium state with verified StoreKit 2 entitlements.
- Made all document conversion and premium PDF tools operate on the device.
- Updated app copy to use direct language and avoid unnecessary dash punctuation.
- Updated the Home screen with Document Tools, recent favorites, privacy controls, and Pro status.
- Made the paywall scrollable and width constrained for iPhone and iPad presentations.
- Delayed onboarding until after the ATT request completes.
- Preserved favorite status when a recent file is opened again.
- Preserved favorites when newer nonfavorite documents are added.
- Removed personal Xcode user settings from source control and added shared project configuration.

### Fixed

- Fixed the paywall being cut off on iPad Air 11 inch layouts.
- Fixed an ATT launch race that could prevent the system permission prompt from appearing.
- Fixed advertising initialization so it begins only after the ATT response.
- Fixed saved signature selection unexpectedly presenting the paywall.
- Fixed stale recent file bookmarks by refreshing them when possible.
- Fixed recent file access by balancing security scoped resource access.
- Fixed corrupt PDF reads silently producing empty documents.
- Fixed page extraction failures being hidden from the user.
- Fixed unsaved autofill profile edits being stored when cancelling.
- Added visible errors and logging for file, conversion, merge, signature, profile, purchase, and export failures.

### Security

- Kept PDF, DOCX, XLSX, JPG, Markdown, OCR, repair, compression, and security processing local to the device.
- Prevented document passwords from being persisted.
- Cleared password fields after processing.
- Required verified StoreKit transactions before granting Pro access.
- Added controls to clear recent bookmarks, saved signatures, and the autofill profile.
- Ensured clearing recent history does not delete or modify original documents.
