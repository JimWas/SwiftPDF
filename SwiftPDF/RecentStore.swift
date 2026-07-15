//
//  RecentStore.swift
//  SwiftPDF
//
//  Created by Jim Washkau on 2/22/26.
//

import Foundation
import SwiftUI
import Combine
import os

final class RecentStore: ObservableObject {
    private let logger = Logger(subsystem: "JimWas.SwiftPDF", category: "RecentStore")
    @Published private(set) var recents: [RecentPDF] = []

    private let storageKey = "swiftpdf.recent-records"
    private let maxRecents = 8

    init() {
        reload()
    }

    func add(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let bookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            logger.error("Failed to create bookmark for \(url.lastPathComponent, privacy: .public)")
            return
        }

        var records = loadRecords()
        let existingRecord = records.first { record in
            guard let existingURL = resolveURL(from: record) else { return false }
            return existingURL.standardizedFileURL == url.standardizedFileURL
        }
        records.removeAll { record in
            guard let existingURL = resolveURL(from: record) else { return false }
            return existingURL.standardizedFileURL == url.standardizedFileURL
        }
        records.insert(
            RecentRecord(
                bookmark: bookmark,
                lastOpened: Date(),
                isFavorite: existingRecord?.isFavorite ?? false
            ),
            at: 0
        )
        let favoriteRecords = records.filter { $0.isFavorite ?? false }
        let recentRecords = records.filter { !($0.isFavorite ?? false) }
        records = favoriteRecords + Array(recentRecords.prefix(maxRecents))
        saveRecords(records)
        reload()
    }

    func toggleFavorite(_ recent: RecentPDF) {
        var records = loadRecords()
        guard let index = records.firstIndex(where: { record in
            guard let existingURL = resolveURL(from: record) else { return false }
            return existingURL.standardizedFileURL == recent.url.standardizedFileURL
        }) else { return }

        let record = records[index]
        records[index] = RecentRecord(
            bookmark: record.bookmark,
            lastOpened: record.lastOpened,
            isFavorite: !(record.isFavorite ?? false)
        )
        saveRecords(records)
        reload()
    }

    /// Removes SwiftPDF's local history and security-scoped bookmarks.
    /// The user's PDF files are never deleted or modified.
    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        recents = []
    }

    private func loadRecords() -> [RecentRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([RecentRecord].self, from: data)) ?? []
    }

    private func saveRecords(_ records: [RecentRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func reload() {
        let records = loadRecords()
        var updatedRecords: [RecentRecord] = []
        var newRecents: [RecentPDF] = []
        var dirty = false

        for record in records {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: record.bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                logger.error("Failed to resolve bookmark; dropping stale recent entry")
                dirty = true
                continue
            }

            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            var bookmark = record.bookmark
            if isStale {
                if let newBookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    bookmark = newBookmark
                    dirty = true
                } else {
                    logger.error("Failed to refresh stale bookmark for \(url.lastPathComponent, privacy: .public)")
                }
            }

            updatedRecords.append(
                RecentRecord(
                    bookmark: bookmark,
                    lastOpened: record.lastOpened,
                    isFavorite: record.isFavorite ?? false
                )
            )

            let modifiedDate = loadModifiedDate(for: url)
            newRecents.append(RecentPDF(
                id: url.absoluteString,
                url: url,
                displayName: url.lastPathComponent,
                lastModified: modifiedDate,
                lastOpened: record.lastOpened,
                bookmark: bookmark,
                isFavorite: record.isFavorite ?? false
            ))
        }

        if dirty {
            saveRecords(updatedRecords)
        }

        recents = newRecents.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }
            let leftDate = lhs.lastModified ?? lhs.lastOpened
            let rightDate = rhs.lastModified ?? rhs.lastOpened
            return leftDate > rightDate
        }
    }

    private func resolveURL(from record: RecentRecord) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: record.bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private func loadModifiedDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}
