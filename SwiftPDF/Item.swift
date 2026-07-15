//
//  Item.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import Foundation

struct RecentRecord: Codable, Equatable {
    let bookmark: Data
    let lastOpened: Date
    let isFavorite: Bool?
}

struct RecentPDF: Identifiable {
    let id: String
    let url: URL
    let displayName: String
    let lastModified: Date?
    let lastOpened: Date
    let bookmark: Data
    let isFavorite: Bool

    var modifiedLabel: String {
        if let lastModified {
            return "Modified \(Self.dateFormatter.string(from: lastModified))"
        }
        return "Modified date unavailable"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
