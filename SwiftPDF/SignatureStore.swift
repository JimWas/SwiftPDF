import Combine
import Foundation
import PencilKit
import SwiftUI
import UIKit
import os

enum SignatureFontStyle: String, CaseIterable, Codable, Identifiable {
    case classic = "Classic"
    case elegant = "Elegant"
    case casual = "Casual"
    case flourish = "Flourish"
    case bold = "Bold"
    case modern = "Modern"

    var id: Self { self }

    private var fontNames: [String] {
        switch self {
        case .classic: ["SnellRoundhand", "SnellRoundhand-Bold"]
        case .elegant: ["SavoyeLetPlain", "SnellRoundhand"]
        case .casual: ["BradleyHandITCTT-Bold", "Noteworthy-Light"]
        case .flourish: ["Zapfino", "SavoyeLetPlain"]
        case .bold: ["MarkerFelt-Wide", "ChalkboardSE-Bold"]
        case .modern: ["Noteworthy-Bold", "MarkerFelt-Thin"]
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        for name in fontNames {
            if let font = UIFont(name: name, size: size) {
                return font
            }
        }
        return UIFont.italicSystemFont(ofSize: size)
    }

    func swiftUIFont(size: CGFloat) -> Font {
        let font = uiFont(size: size)
        return .custom(font.fontName, size: size)
    }
}

struct SavedSignature: Identifiable, Codable {
    let id: UUID
    let drawingData: Data?
    let typedName: String?
    let fontStyle: SignatureFontStyle?
    let date: Date

    var drawing: PKDrawing {
        guard let drawingData else { return PKDrawing() }
        return (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }

    var renderedImage: UIImage? {
        if let typedName, !typedName.isEmpty {
            return SignatureRenderer.image(
                text: typedName,
                style: fontStyle ?? .classic,
                fontSize: 92
            )
        }

        let drawing = drawing
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        return drawing.image(from: bounds, scale: 3)
    }
}

enum SignatureRenderer {
    static func image(
        text: String,
        style: SignatureFontStyle,
        fontSize: CGFloat
    ) -> UIImage? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let font = style.uiFont(size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        let measured = (value as NSString).size(withAttributes: attributes)
        let horizontalPadding: CGFloat = 28
        let verticalPadding: CGFloat = style == .flourish ? 42 : 24
        let size = CGSize(
            width: ceil(measured.width + horizontalPadding * 2),
            height: ceil(measured.height + verticalPadding * 2)
        )
        guard size.width > 1, size.height > 1 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            (value as NSString).draw(
                at: CGPoint(x: horizontalPadding, y: verticalPadding),
                withAttributes: attributes
            )
        }
    }
}

@MainActor
final class SignatureStore: ObservableObject {
    @Published var signatures: [SavedSignature] = []
    private let saveKey = "SwiftPDF_SavedSignatures"
    private let logger = Logger(subsystem: "JimWas.SwiftPDF", category: "SignatureStore")

    init() {
        load()
    }

    func add(drawing: PKDrawing) {
        let signature = SavedSignature(
            id: UUID(),
            drawingData: drawing.dataRepresentation(),
            typedName: nil,
            fontStyle: nil,
            date: Date()
        )
        signatures.insert(signature, at: 0)
        save()
    }

    func addTyped(name: String, style: SignatureFontStyle) {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let signature = SavedSignature(
            id: UUID(),
            drawingData: nil,
            typedName: value,
            fontStyle: style,
            date: Date()
        )
        signatures.insert(signature, at: 0)
        save()
    }

    func remove(at offsets: IndexSet) {
        signatures.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        signatures = []
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(signatures)
            UserDefaults.standard.set(encoded, forKey: saveKey)
        } catch {
            logger.error("Failed to encode signatures: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            return
        }

        do {
            signatures = try JSONDecoder().decode([SavedSignature].self, from: data)
        } catch {
            logger.error("Failed to decode saved signatures: \(error.localizedDescription)")
        }
    }
}
