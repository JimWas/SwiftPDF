import CoreGraphics
import Foundation
import PDFKit
import UIKit
import ZIPFoundation

enum PDFToJPGMode: String, CaseIterable, Identifiable {
    case pages = "Pages"
    case images = "Images"

    var id: Self { self }

    var detail: String {
        switch self {
        case .pages: "Convert every PDF page into a JPG image."
        case .images: "Extract embedded images from the PDF without rendering the full page."
        }
    }
}

enum JPGExportQuality: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case high = "High"

    var id: Self { self }

    var scale: CGFloat { self == .high ? 3 : 2 }
    var compression: CGFloat { self == .high ? 0.92 : 0.78 }
}

enum ImagePDFOrientation: String, CaseIterable, Identifiable {
    case portrait = "Portrait"
    case landscape = "Landscape"

    var id: Self { self }
}

enum ImagePDFPageSize: String, CaseIterable, Identifiable {
    case fit = "Fit"
    case a4 = "A4"
    case letter = "Letter"

    var id: Self { self }
}

enum ImagePDFMargin: String, CaseIterable, Identifiable {
    case none = "None"
    case small = "Small"
    case large = "Large"

    var id: Self { self }

    var points: CGFloat {
        switch self {
        case .none: 0
        case .small: 24
        case .large: 54
        }
    }
}

struct PDFToJPGResult {
    let archive: Data
    let imageCount: Int
}

enum PDFImageConversionError: LocalizedError {
    case unreadablePDF
    case lockedPDF
    case noImages
    case unreadableImage
    case archiveFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unreadablePDF: "The selected file is not a readable PDF."
        case .lockedPDF: "This PDF is protected with a password. Unlock it before converting it."
        case .noImages: "No images could be created or extracted from this PDF."
        case .unreadableImage: "One or more selected JPG files could not be read."
        case .archiveFailed: "SwiftPDF could not package the JPG images for export."
        case .exportFailed: "SwiftPDF could not create the PDF."
        }
    }
}

enum PDFToJPGService {
    static func convert(data: Data, mode: PDFToJPGMode, quality: JPGExportQuality) throws -> PDFToJPGResult {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw PDFImageConversionError.unreadablePDF
        }
        guard !document.isLocked else { throw PDFImageConversionError.lockedPDF }

        let images: [Data]
        switch mode {
        case .pages:
            images = try renderedPages(from: document, quality: quality)
        case .images:
            images = try extractedImages(from: data, compression: quality.compression)
        }

        guard !images.isEmpty else { throw PDFImageConversionError.noImages }
        return PDFToJPGResult(archive: try makeArchive(images: images), imageCount: images.count)
    }

    private static func renderedPages(from document: PDFDocument, quality: JPGExportQuality) throws -> [Data] {
        var output: [Data] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var bounds = page.bounds(for: .mediaBox)
            if page.rotation == 90 || page.rotation == 270 {
                bounds.size = CGSize(width: bounds.height, height: bounds.width)
            }
            let target = cappedSize(
                CGSize(width: bounds.width * quality.scale, height: bounds.height * quality.scale),
                maximumDimension: quality == .high ? 4_800 : 3_200
            )
            let image = page.thumbnail(of: target, for: .mediaBox)
            if let jpg = image.jpegData(compressionQuality: quality.compression) {
                output.append(jpg)
            }
        }
        guard !output.isEmpty else { throw PDFImageConversionError.noImages }
        return output
    }

    private static func extractedImages(from data: Data, compression: CGFloat) throws -> [Data] {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else {
            throw PDFImageConversionError.unreadablePDF
        }

        let collector = PDFEmbeddedImageCollector(compression: compression)
        for pageNumber in 1...document.numberOfPages {
            guard let page = document.page(at: pageNumber),
                  let pageDictionary = page.dictionary,
                  let resources = pageDictionary.resourceDictionary,
                  let objects = resources.xObjectDictionary else { continue }
            collector.collect(from: objects)
        }
        guard !collector.images.isEmpty else { throw PDFImageConversionError.noImages }
        return collector.images
    }

    private static func makeArchive(images: [Data]) throws -> Data {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPDF-JPG-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = root.appendingPathExtension("zip")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: archiveURL)
        }

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let digits = max(2, String(images.count).count)
            for (index, image) in images.enumerated() {
                let number = String(format: "%0*d", digits, index + 1)
                try image.write(to: root.appendingPathComponent("Image \(number).jpg"), options: .atomic)
            }
            try FileManager.default.zipItem(
                at: root,
                to: archiveURL,
                shouldKeepParent: false,
                compressionMethod: .deflate
            )
            return try Data(contentsOf: archiveURL)
        } catch {
            throw PDFImageConversionError.archiveFailed
        }
    }

    private static func cappedSize(_ size: CGSize, maximumDimension: CGFloat) -> CGSize {
        let largest = max(size.width, size.height)
        guard largest > maximumDimension else { return size }
        let scale = maximumDimension / largest
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

enum JPGToPDFService {
    static func convert(
        imageData: [Data],
        orientation: ImagePDFOrientation,
        pageSize: ImagePDFPageSize,
        margin: ImagePDFMargin
    ) throws -> Data {
        let images = imageData.compactMap(UIImage.init(data:))
        guard images.count == imageData.count, !images.isEmpty else {
            throw PDFImageConversionError.unreadableImage
        }

        let firstBounds = bounds(for: images[0], orientation: orientation, pageSize: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds)
        let output = renderer.pdfData { context in
            for image in images {
                let pageBounds = bounds(for: image, orientation: orientation, pageSize: pageSize)
                context.beginPage(withBounds: pageBounds, pageInfo: [:])
                UIColor.white.setFill()
                context.cgContext.fill(pageBounds)

                let available = pageBounds.insetBy(dx: margin.points, dy: margin.points)
                let target = aspectFit(image.size, inside: available)
                image.draw(in: target)
            }
        }
        guard !output.isEmpty else { throw PDFImageConversionError.exportFailed }
        return output
    }

    private static func bounds(
        for image: UIImage,
        orientation: ImagePDFOrientation,
        pageSize: ImagePDFPageSize
    ) -> CGRect {
        var size: CGSize
        switch pageSize {
        case .fit:
            let longestSide: CGFloat = 1_200
            let imageSize = image.size
            let scale = min(1, longestSide / max(imageSize.width, imageSize.height))
            size = CGSize(width: max(72, imageSize.width * scale), height: max(72, imageSize.height * scale))
        case .a4:
            size = CGSize(width: 595.2, height: 841.8)
        case .letter:
            size = CGSize(width: 612, height: 792)
        }

        let shouldBeLandscape = orientation == .landscape
        if shouldBeLandscape != (size.width > size.height) {
            size = CGSize(width: size.height, height: size.width)
        }
        return CGRect(origin: .zero, size: size)
    }

    private static func aspectFit(_ imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private final class PDFEmbeddedImageCollector {
    let compression: CGFloat
    var images: [Data] = []

    init(compression: CGFloat) {
        self.compression = compression
    }

    func collect(from dictionary: CGPDFDictionaryRef) {
        CGPDFDictionaryApplyFunction(
            dictionary,
            pdfImageDictionaryApplier,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func collect(object: CGPDFObjectRef) {
        var stream: CGPDFStreamRef?
        guard CGPDFObjectGetValue(object, .stream, &stream), let stream,
              let dictionary = CGPDFStreamGetDictionary(stream),
              let subtype = dictionary.name(for: "Subtype") else { return }

        if subtype == "Image" {
            if let jpg = jpgData(from: stream, dictionary: dictionary) {
                images.append(jpg)
            }
        } else if subtype == "Form",
                  let resources = dictionary.resourceDictionary,
                  let objects = resources.xObjectDictionary {
            collect(from: objects)
        }
    }

    private func jpgData(from stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef) -> Data? {
        var format = CGPDFDataFormat.raw
        guard let copied = CGPDFStreamCopyData(stream, &format) else { return nil }
        let data = copied as Data

        if let image = UIImage(data: data) {
            return image.jpegData(compressionQuality: compression)
        }

        guard format == .raw,
              let width = dictionary.integer(for: "Width"),
              let height = dictionary.integer(for: "Height"),
              let bits = dictionary.integer(for: "BitsPerComponent"),
              bits == 8,
              let colorName = dictionary.colorSpaceName else { return nil }

        let colorSpace: CGColorSpace
        let components: Int
        switch colorName {
        case "DeviceGray", "G":
            colorSpace = CGColorSpaceCreateDeviceGray()
            components = 1
        case "DeviceRGB", "RGB":
            colorSpace = CGColorSpaceCreateDeviceRGB()
            components = 3
        case "DeviceCMYK", "CMYK":
            colorSpace = CGColorSpaceCreateDeviceCMYK()
            components = 4
        default:
            return nil
        }

        let expectedBytes = width * height * components
        guard data.count >= expectedBytes,
              let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bits,
                bitsPerPixel: bits * components,
                bytesPerRow: width * components,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: compression)
    }
}

private let pdfImageDictionaryApplier: CGPDFDictionaryApplierFunction = { _, object, info in
    guard let info else { return }
    Unmanaged<PDFEmbeddedImageCollector>.fromOpaque(info).takeUnretainedValue().collect(object: object)
}

private extension CGPDFDictionaryRef {
    var resourceDictionary: CGPDFDictionaryRef? {
        var value: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(self, "Resources", &value) ? value : nil
    }

    var xObjectDictionary: CGPDFDictionaryRef? {
        var value: CGPDFDictionaryRef?
        return CGPDFDictionaryGetDictionary(self, "XObject", &value) ? value : nil
    }

    func name(for key: String) -> String? {
        var value: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(self, key, &value), let value else { return nil }
        return String(cString: value)
    }

    func integer(for key: String) -> Int? {
        var value: CGPDFInteger = 0
        return CGPDFDictionaryGetInteger(self, key, &value) ? value : nil
    }

    var colorSpaceName: String? {
        if let direct = name(for: "ColorSpace") { return direct }
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(self, "ColorSpace", &array), let array else { return nil }
        var value: UnsafePointer<CChar>?
        guard CGPDFArrayGetName(array, 0, &value), let value else { return nil }
        return String(cString: value)
    }
}
