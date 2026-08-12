# SwiftPDF Developer Documentation

This document is the technical handoff for developers maintaining SwiftPDF. It describes the current architecture, external configuration, persistence, premium access, testing expectations, and release process.

Last reviewed: July 15, 2026  
Repository: `https://github.com/JimWas/SwiftPDF`  
Bundle identifier: `JimWas.SwiftPDF`  
Minimum iOS version: iOS 17.0  
Current marketing version: 1.0

## 1. Product Overview

SwiftPDF is a local first PDF editor and document conversion app. Users can open, scan, merge, edit, sign, organize, convert, protect, save, and share documents. Core document processing is performed on the device.

The app has a free tier supported by advertising and a Pro tier unlocked by monthly, annual, or lifetime App Store purchases.

## 2. Requirements

- Xcode 17 or newer
- Swift 5
- iOS 17.0 or newer
- An Apple Developer account for signing and device testing
- App Store Connect access for subscription testing and releases
- An AdMob account if the production ad identifiers need to be changed

The project uses Swift Package Manager. Xcode resolves the packages listed in `Package.resolved`.

Current package dependencies:

- Google Mobile Ads
- Google User Messaging Platform
- ZIPFoundation

## 3. Getting Started

Clone and open the project:

```bash
git clone https://github.com/JimWas/SwiftPDF.git
cd SwiftPDF
open SwiftPDF.xcodeproj
```

In Xcode:

1. Select the `SwiftPDF` scheme.
2. Confirm the signing team and bundle identifier.
3. Select a simulator or connected device.
4. Build and run.

Command line simulator build:

```bash
xcodebuild \
  -project SwiftPDF.xcodeproj \
  -scheme SwiftPDF \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Build for the iPad simulator configuration used during development:

```bash
xcodebuild \
  -project SwiftPDF.xcodeproj \
  -scheme SwiftPDF \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3),OS=26.2' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 4. Project Structure

```text
SwiftPDF/
├── SwiftPDF.xcodeproj
├── Documentation.md
├── Changelog.md
├── README.md
└── SwiftPDF/
    ├── SwiftPDFApp.swift
    ├── ContentView.swift
    ├── PDFEditorController.swift
    ├── PDFEditorView.swift
    ├── DocumentToolsView.swift
    ├── LocalDocumentConverter.swift
    ├── PDFImageConversionService.swift
    ├── PremiumPDFTools.swift
    ├── StoreManager.swift
    ├── ProManager.swift
    ├── PaywallView.swift
    ├── AdMobService.swift
    ├── RecentStore.swift
    ├── SignatureStore.swift
    ├── UserProfileStore.swift
    ├── LegalDocumentView.swift
    ├── Info.plist
    └── Assets.xcassets
```

### Application and navigation

| File | Responsibility |
| --- | --- |
| `SwiftPDFApp.swift` | App entry point, ATT request sequencing, and AdMob startup |
| `ContentView.swift` | Home screen, import flows, scanner, recent files, favorites, and primary sheets |
| `OnboardingView.swift` | First launch tutorial, Skip Tutorial action, and replayable tutorial content |
| `SettingsView.swift` | Pro status, restore purchases, privacy controls, tutorial replay, legal links, and app information |
| `PaywallView.swift` | Product loading, plan selection, purchase controls, restore controls, legal links, and adaptive scrolling |

### PDF editing

| File | Responsibility |
| --- | --- |
| `PDFEditorController.swift` | Editing session state, active page, drawings, inserted images, page operations, OCR, and presentation state |
| `PDFEditorView.swift` | SwiftUI editor, PDFKit and PencilKit bridge, palettes, page manager, signatures, form filling, and export renderer |
| `SignedPDFDocument.swift` | `FileDocument` wrapper used by the exporter |
| `PDFActivityItemSource.swift` | Native sharing metadata and activity item support |
| `PDFMergeService.swift` | Combines selected PDF documents |
| `WatermarkEditorView.swift` | Batch watermark configuration |

### Importing, scanning, and conversion

| File | Responsibility |
| --- | --- |
| `OpenPDFPicker.swift` | Single and multiple PDF document pickers |
| `DocumentScannerView.swift` | VisionKit document scanner bridge |
| `OCRService.swift` | Vision text recognition |
| `DocumentToolsView.swift` | Tool catalog, premium gating, tool options, import, processing, and export flow |
| `LocalDocumentConverter.swift` | Compression, PDF to DOCX, DOCX to PDF, XLSX to PDF, and archive helpers |
| `PDFImageConversionService.swift` | PDF to JPG, embedded image extraction, JPG to PDF, layout options, and ZIP output |
| `PremiumPDFTools.swift` | PDF to Markdown, repair, unlock, and protect services |

### State, monetization, and privacy

| File | Responsibility |
| --- | --- |
| `StoreManager.swift` | StoreKit 2 products, purchases, transaction verification, restore, and entitlement updates |
| `ProManager.swift` | Compatibility facade exposing Pro state and free OCR usage limits |
| `AdMobService.swift` | Native, interstitial, and rewarded ads |
| `RecentStore.swift` | Security scoped bookmarks, recent documents, favorites, and clearing history |
| `SignatureStore.swift` | Saved PencilKit drawings, typed signatures, font styles, and signature rendering |
| `UserProfileStore.swift` | Local autofill name, email, phone, and address |
| `LegalDocumentView.swift` | Privacy policy content and Apple standard EULA URL |

## 5. Launch Sequence and App Tracking Transparency

The launch order in `SwiftPDFApp.swift` is intentional and must not be casually rearranged.

1. The app displays `LaunchPreparationView`.
2. The scene must reach the active state.
3. The app waits briefly to avoid competing system presentations.
4. If tracking status is not determined, the ATT request is displayed.
5. The app waits for the user response.
6. AdMob is configured.
7. `ContentView` is displayed.
8. First launch onboarding may then appear.

This ordering prevents onboarding or another permission sheet from suppressing the ATT prompt. Do not initialize Google Mobile Ads before the ATT request completes while App Store privacy answers declare tracking.

The tracking purpose string is stored under `NSUserTrackingUsageDescription` in `Info.plist`.

To retest ATT on a physical device:

1. Enable **Settings > Privacy & Security > Tracking > Allow Apps to Request to Track**.
2. Delete SwiftPDF from the device.
3. Reinstall it from Xcode or TestFlight.
4. Record the launch from a fresh installation.

## 6. Editor Architecture

`PDFEditorController` is the primary mutable state owner for an editing session. It owns the `PDFDocument`, current page, PencilKit drawings, inserted images, selected tools, text formatting, and sheet or alert state.

`EditorView` observes the controller and provides the SwiftUI shell. `PDFEditorContainer` bridges SwiftUI to UIKit. Its coordinator synchronizes `PDFView`, `PKCanvasView`, gestures, inserted image overlays, and page changes.

Text Tools includes Add Text and Correct Text or Date. Correction mode uses `PDFPage.selectionForWord(at:)` when selectable text is available. It creates an opaque free text annotation over the source bounds and inserts the replacement. For scanned or flattened pages without selectable text, it creates a movable correction box at the tapped location. Corrections are identified by `correction=1` in the annotation user name and store their background as a hexadecimal `background` value. Both markers must remain intact when text styles change.

Text replacements support the system font plus Helvetica, Arial, Times New Roman, Georgia, Avenir Next, Futura, Courier, Serif, Rounded, and Mono choices. Named fonts use built in iOS fonts and fall back to the system font if a requested face is unavailable.

Identify Font first checks the attributed string returned by a selectable PDF word and maps its embedded `UIFont` metadata to the nearest editable family. When text is flattened or scanned, `FontIdentifier` runs Vision OCR on a local page thumbnail, crops the nearest recognized text line, and compares its Vision feature print with rendered regular, bold, italic, and bold italic candidates. Scan results are intentionally presented as a closest match because rasterized documents do not retain authoritative font metadata. No page image or recognized text leaves the device.

### Exporting and flattening

The main export implementation lives in `PDFExporter` inside `PDFEditorView.swift`.

The exporter redraws each PDF page and then renders app managed content such as:

- PencilKit strokes
- Text annotations
- Text and date corrections with opaque replacement backgrounds
- Shapes and arrows
- Inserted images
- Saved signatures
- Watermarks
- Filled form values

Any new visual editor object must also be added to the export path. A feature that appears in the editor but is not handled by `PDFExporter` may disappear from the saved file.

Saved signatures can contain either PencilKit drawing data or a typed signer name with a `SignatureFontStyle`. `SavedSignature.renderedImage` provides the shared rendering path used by the signature library and PDF editor. Keep this path compatible with both formats so signatures saved by older app versions remain usable.

Coordinate systems require care. PDFKit commonly uses a lower left origin, while UIKit uses an upper left origin. Existing conversion and transform helpers should be reused when adding overlays.

## 7. Document Tools

The tool catalog is defined by `LocalDocumentTool` in `DocumentToolsView.swift`.

| Tool | Access | Input | Output | Implementation |
| --- | --- | --- | --- | --- |
| Compress PDF | Free | PDF | PDF | `PDFCompressionService` |
| PDF to Word | Free | PDF | DOCX | `PDFToWordService` |
| Word to PDF | Free | DOCX | PDF | `OfficeToPDFService` |
| Excel to PDF | Free | XLSX | PDF | `OfficeToPDFService` |
| PDF to JPG | Pro | PDF | ZIP of JPG files | `PDFToJPGService` |
| JPG to PDF | Pro | One or more JPG files | PDF | `JPGToPDFService` |
| PDF to Markdown | Pro | PDF | Markdown | `PDFMarkdownService` |
| Repair PDF | Pro | PDF | PDF | `PDFRepairService` |
| Unlock PDF | Pro | Protected PDF and password | PDF | `PDFSecurityService` |
| Protect PDF | Pro | PDF and new password | PDF | `PDFSecurityService` |

All tools use the system file importer and exporter. Selected files are read through security scoped access. Temporary archive and conversion files are deleted after processing.

### Adding another document tool

1. Add a case to `LocalDocumentTool`.
2. Add its title, detail, symbol, color, input types, output type, supported input label, and premium status.
3. Add any configuration state to `DocumentToolOperationView`.
4. Add an options view when user choices are required.
5. Add a processing label.
6. Add the conversion case to `handleSelection`.
7. Return a single `Data` result that `ConvertedFileDocument` can export.
8. Update the paywall, onboarding, Settings, privacy policy, README, and changelog if the feature affects those descriptions.
9. Test success, cancellation, unreadable input, protected input, and export failure.

## 8. StoreKit and Pro Access

`StoreManager` is the source of truth for verified App Store entitlements. `ProManager` mirrors that value so older editor code can continue reading `ProManager.shared.isPro`.

Product identifiers must match App Store Connect exactly:

```text
JimWas.SwiftPDF.pro.monthly
JimWas.SwiftPDF.pro.annual
JimWas.SwiftPDF.pro.lifetime
```

The shared Xcode scheme uses `SwiftPDF.storekit` for local StoreKit testing. This configuration provides local prices and purchase transactions without contacting App Store Connect.

### Resetting local StoreKit purchases

While the app is running from Xcode:

1. Choose **Debug > StoreKit > Manage Transactions**.
2. Select the subscription or lifetime transaction.
3. Delete the transaction.
4. Relaunch the app.

If the cached UI state persists briefly, delete the development app from the device and reinstall it. The verified StoreKit entitlement remains authoritative.

### Sandbox testing

To use live App Store Connect products, disable the StoreKit configuration in the Run scheme and sign into a Sandbox Apple Account on the device. Product metadata changes may take time to appear in the sandbox.

### Premium gating

Document tools use `LocalDocumentTool.isPremium`. Editor actions check `ProManager.shared.isPro` and present the paywall when required.

Current Pro benefits include:

- No ads
- Unlimited OCR
- Unlimited saved drawn and typed signatures
- Six typed signature font styles
- Password protection
- Batch watermarking
- Smart autofill
- Export compression controls
- PDF to JPG
- JPG to PDF
- PDF to Markdown
- PDF repair
- PDF unlock
- Advanced document tools

The free tier currently allows three OCR operations and one saved signature.

## 9. Advertising

`AdMobService` manages:

- A native ad card on Home
- Interstitial ads after eligible actions
- A rewarded ad around the first save flow

Pro users bypass ad presentation.

The AdMob application identifier and SKAdNetwork identifiers are in `Info.plist`. Ad unit identifiers are in `AdMobService.swift`.

Before changing advertising behavior:

1. Review the Google Mobile Ads data collection documentation.
2. Update App Store Connect privacy answers when collection or tracking behavior changes.
3. Keep ATT ahead of advertising initialization if tracking remains declared.
4. Test both Allow and Ask App Not to Track paths.
5. Test with a Pro entitlement to confirm ads remain disabled.

## 10. Local Persistence

SwiftPDF does not maintain a developer backend. The following local keys are currently used:

| Key | Contents | Owner |
| --- | --- | --- |
| `swiftpdf.hasCompletedOnboarding` | First launch tutorial completion | `ContentView` |
| `swiftpdf.recent-records` | Recent file bookmarks, dates, and favorite state | `RecentStore` |
| `SwiftPDF_SavedSignatures` | Encoded PencilKit or typed signatures with font styles | `SignatureStore` |
| `SwiftPDF_UserProfile` | Autofill profile | `UserProfileStore` |
| `SwiftPDF_IsPro` | Temporary UI cache of StoreKit entitlement state | `ProManager` |
| `SwiftPDF_OCRCount` | Free OCR usage count | `ProManager` |

The Pro cache is not an entitlement authority. `StoreManager` refreshes verified transactions and overwrites it.

Recent files are stored as security scoped bookmarks. Clearing recents removes bookmarks and favorite state but never deletes the original PDF files.

Signatures and profile data are stored in `UserDefaults`, not Keychain. Do not store document passwords. Password fields are cleared after processing.

## 11. Privacy and Security Expectations

- Document conversion must remain on the device unless product requirements and disclosures are deliberately changed.
- Never add network upload code to a conversion service without updating the privacy policy, App Store privacy answers, review notes, and user interface.
- Always balance `startAccessingSecurityScopedResource()` with `stopAccessingSecurityScopedResource()`.
- Do not log document contents, signatures, profile values, or passwords.
- Temporary files should use unique names and be removed with `defer`.
- Password protected PDF operations must fail safely when the password is missing or incorrect.
- Only verified StoreKit transactions grant Pro access.

## 12. Testing Checklist

### Core document flow

- Open a PDF from local Files.
- Open a PDF from iCloud Drive.
- Reopen it from Recent PDFs after relaunching.
- Favorite and unfavorite a recent PDF.
- Clear recents and confirm the original file remains.
- Draw, add text, insert an image, add a signature, and export.
- Reorder, rotate, extract, and delete pages.
- Save all pages and only the current page.
- Overwrite an original file and save a new copy.

### Conversion tools

- Test a single page and multipage PDF.
- Test born digital and scanned PDFs.
- Test simple and complex DOCX and XLSX files.
- Test PDF page rendering to JPG at both quality levels.
- Test embedded image extraction.
- Test one and multiple JPG files to PDF.
- Test portrait, landscape, Fit, A4, Letter, and all margin choices.
- Confirm ZIP output opens in Files.
- Test protected, damaged, empty, and unsupported files.

### Purchases

- Load all three products.
- Buy monthly, annual, and lifetime products in separate reset sessions.
- Restore purchases.
- Delete or expire transactions and confirm Pro turns off.
- Confirm paid tools open for Pro and show the paywall for free users.
- Confirm all prices are provided by StoreKit rather than hard coded.

### Privacy and advertising

- Fresh install with ATT status not determined.
- ATT Allow path.
- ATT Ask App Not to Track path.
- Confirm no ad request starts before the ATT response.
- Confirm ads appear only for free users.
- Confirm camera permission appears when scanning begins.

### Layout and accessibility

- iPhone portrait and landscape.
- iPad portrait and landscape, including compatibility presentation.
- Paywall scrolling on an iPad Air 11 inch layout.
- Large Dynamic Type.
- VoiceOver labels for close, favorite, settings, purchase, and export controls.
- Light and dark appearance.

## 13. Known Limitations

- Office conversion is intentionally best effort. Complex layouts, charts, macros, formulas, uncommon fonts, and advanced formatting may be simplified.
- PDF compression flattens interactive content such as forms, links, annotations, and selectable text.
- PDF repair can only recover content that PDFKit or Core Graphics can still read.
- Embedded image extraction supports common JPEG, JPEG 2000, raw grayscale, RGB, and CMYK image streams. Unusual PDF color spaces or masks may not extract perfectly.
- OCR quality depends on scan resolution, contrast, orientation, and language support from Vision.
- The project currently has no dedicated automated test target. High risk conversion and purchase changes require manual device testing.
- Local signatures and autofill data use `UserDefaults`. This is appropriate for the current design but is not a substitute for Keychain when storing secrets.

## 14. App Store Release Process

1. Update `MARKETING_VERSION` only for a new App Store version.
2. Increase `CURRENT_PROJECT_VERSION` for every uploaded build.
3. Run a clean simulator build.
4. Test on a physical device using the latest operating system available.
5. Test the complete paywall on iPhone and iPad.
6. Record the ATT flow from a fresh installation when review notes request it.
7. Select **Any iOS Device** and choose **Product > Archive**.
8. Validate and upload through Organizer.
9. Select the processed build in App Store Connect.
10. Confirm subscription products are attached to the version when required.
11. Update App Review Information, credentials, notes, and attachments.
12. Confirm the App Description contains the Apple standard EULA link:

```text
Terms of Use (EULA):
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

13. Confirm the privacy policy URL is publicly accessible.
14. Submit for review.

Never assume a successful local StoreKit purchase means App Store Connect products are ready. Verify agreements, tax and banking status, product availability, localization, pricing, screenshots, and review information separately.

## 15. Troubleshooting

### Products do not load

- Confirm the shared scheme selects `SwiftPDF.storekit` for local testing.
- Confirm product identifiers match `StoreManager` exactly.
- For sandbox testing, confirm products are active in App Store Connect.
- Check network connectivity and StoreKit logs.

### ATT prompt does not appear

- Confirm the app was deleted and reinstalled.
- Confirm Allow Apps to Request to Track is enabled.
- Confirm `NSUserTrackingUsageDescription` exists.
- Confirm the request occurs while the scene is active.
- Confirm no other permission or onboarding sheet is being presented at the same time.

### Recent file cannot reopen

- Confirm the bookmark resolves.
- Refresh stale bookmarks when possible.
- Confirm security scoped access remains active for the entire read or write operation.
- Test from both local Files and iCloud Drive.

### Exported content is missing

- Confirm the editor object is represented in controller state.
- Confirm `PDFExporter` renders the object.
- Check page coordinate transforms and rotation.
- Test at multiple page sizes and orientations.

### Paywall is cut off

- Keep the paywall inside a `ScrollView`.
- Do not reintroduce a fixed vertical stack that assumes a specific sheet height.
- Test with all three StoreKit products, long localized descriptions, landscape orientation, and large text.

## 16. Contribution Guidelines

- Keep user facing document processing local unless a product decision explicitly changes that policy.
- Preserve existing user data when changing `Codable` persistence models. New persisted fields should be optional or have a migration path.
- Avoid hard coded StoreKit prices.
- Keep personal `xcuserdata` out of Git.
- Update `Documentation.md` when architecture or release procedures change.
- Update `Changelog.md` for every user visible change.
- Run `git diff --check` before committing.
- Build the iOS simulator target before opening a pull request.
