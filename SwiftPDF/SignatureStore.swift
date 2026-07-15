import Combine
import Foundation
import PencilKit
import SwiftUI
import os

struct SavedSignature: Identifiable, Codable {
    let id: UUID
    let drawingData: Data
    let date: Date

    var drawing: PKDrawing {
        (try? PKDrawing(data: drawingData)) ?? PKDrawing()
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
