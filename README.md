# SwiftPDF

SwiftPDF is a minimalist iOS PDF editor for opening, signing, editing, scanning, saving, and sharing PDFs in seconds.

The app is built with SwiftUI, PDFKit, PencilKit, VisionKit, StoreKit 2, and Google AdMob. The focus is speed: no heavy onboarding, no cluttered menus, and no desktop-style complexity squeezed onto a phone.

## Features

- Open PDFs from Files using the native document picker
- Scan paper documents into PDFs with VisionKit
- View PDFs with a clean PDFKit editor
- Sign with Apple Pencil or finger using PencilKit
- Save reusable signatures
- Add and edit text annotations
- Change text font, size, color, bold, italic, and strikethrough
- Add shapes, lines, and arrows
- Insert images and signatures as movable/resizable objects
- Reorder, delete, extract, and bulk delete pages
- Save all pages or only the current page
- Overwrite the current PDF or save as a new file
- Share exported PDFs through the native iOS share sheet
- OCR text extraction for supported documents
- Optional password protection
- Optional watermarking
- Recent files support with security-scoped bookmarks
- AdMob monetization with Pro upgrade support
- StoreKit 2 subscriptions and lifetime Pro purchase

## Tech Stack

- Swift
- SwiftUI
- PDFKit
- PencilKit
- VisionKit
- Vision
- StoreKit 2
- Google Mobile Ads SDK
- UserMessagingPlatform

## Requirements

- Xcode 17 or newer
- iOS 17.0+
- Swift 5
- Apple Developer account for device testing, StoreKit, signing, and App Store upload
- AdMob account if shipping ads

## Project Structure

```text
SwiftPDF/
  SwiftPDF.xcodeproj
  SwiftPDF/
    SwiftPDFApp.swift
    ContentView.swift
    PDFEditorView.swift
    PDFEditorController.swift
    DocumentScannerView.swift
    OpenPDFPicker.swift
    SignatureStore.swift
    RecentStore.swift
    StoreManager.swift
    ProManager.swift
    AdMobService.swift
    OCRService.swift
    LegalDocumentView.swift
    Assets.xcassets/
```

## Getting Started

1. Open the project in Xcode:

```bash
open SwiftPDF.xcodeproj
```

2. Select the `SwiftPDF` scheme.

3. Choose a simulator or connected iPhone.

4. Build and run.

## Command Line Builds

Simulator build:

```bash
xcodebuild -project SwiftPDF.xcodeproj -scheme SwiftPDF -destination 'generic/platform=iOS Simulator' build
```

Release device build:

```bash
xcodebuild -project SwiftPDF.xcodeproj -scheme SwiftPDF -configuration Release -destination 'generic/platform=iOS' build
```

## Core Architecture

`PDFEditorController` owns the editing session state:

- current `PDFDocument`
- active page
- drawing state
- text style state
- inserted images
- page management
- selected editable objects

`PDFEditorView` provides the SwiftUI editor shell and bridges PDFKit/PencilKit using `UIViewRepresentable`.

`PDFExporter` flattens the PDF by rendering the base PDF page, then drawing text annotations, shapes, images, and PencilKit strokes into a final exported PDF.

## Monetization

The app includes:

- AdMob native, interstitial, and rewarded ad support
- StoreKit 2 Pro purchases
- Monthly, annual, and lifetime Pro options
- Ad suppression for Pro users

Expected in-app purchase product IDs:

```text
JimWas.SwiftPDF.pro.lifetime
JimWas.SwiftPDF.pro.monthly
JimWas.SwiftPDF.pro.annual
```

Before App Store submission, create matching products in App Store Connect and confirm AdMob app/ad unit IDs are approved for the app bundle.

## Privacy Notes

SwiftPDF is designed to keep document editing local to the device. PDFs, signatures, and profile/autofill data are handled locally unless the user explicitly shares or saves files through iOS system interfaces.

If ads are enabled, App Tracking Transparency and AdMob privacy declarations are required.

## App Store Checklist

See `../APP_STORE_CHECKLIST.md` for submission notes, including:

- StoreKit product setup
- App privacy questionnaire guidance
- AdMob configuration
- Privacy Policy hosting
- StoreKit testing

## GitHub Repository Description

Minimal SwiftUI PDF editor for iOS with PDFKit, PencilKit signing, page management, document scanning, text/image editing, sharing, AdMob, and StoreKit Pro upgrades.

## License

All rights reserved unless a license file is added.
