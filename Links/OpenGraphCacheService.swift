//
//  OpenGraphCacheService.swift
//  Links
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
import SQLite3

class OpenGraphCacheService {
    static let shared = OpenGraphCacheService()

    private var db: OpaquePointer?
    private let cacheURL: URL

    private init() {
        // Store cache in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent("Links")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        cacheURL = appFolder.appendingPathComponent("opengraph_cache.db")

        openDatabase()
        createTableIfNeeded()
    }

    private func openDatabase() {
        let result = sqlite3_open(cacheURL.path, &db)
        if result != SQLITE_OK {
            print("Error opening cache database: \(result)")
        }
    }

    private func createTableIfNeeded() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS opengraph_cache (
            url TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            image_url TEXT,
            site_name TEXT,
            cached_at INTEGER,
            UNIQUE(url)
        );

        CREATE INDEX IF NOT EXISTS idx_cached_at ON opengraph_cache(cached_at);
        """

        var error: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, createTableSQL, nil, nil, &error)

        if result != SQLITE_OK {
            if let error = error {
                print("Error creating table: \(String(cString: error))")
                sqlite3_free(error)
            }
        }
    }

    func getCachedData(for url: URL) -> OpenGraphData? {
        let query = "SELECT title, description, image_url, site_name, cached_at FROM opengraph_cache WHERE url = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer {
            sqlite3_finalize(statement)
        }

        let urlString = url.absoluteString
        sqlite3_bind_text(statement, 1, (urlString as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        var title: String?
        if let cString = sqlite3_column_text(statement, 0) {
            title = String(cString: cString)
        }

        var description: String?
        if let cString = sqlite3_column_text(statement, 1) {
            description = String(cString: cString)
        }

        var imageURL: String?
        if let cString = sqlite3_column_text(statement, 2) {
            imageURL = String(cString: cString)
        }

        var siteName: String?
        if let cString = sqlite3_column_text(statement, 3) {
            siteName = String(cString: cString)
        }

        let cachedAt = sqlite3_column_int64(statement, 4)

        // Check if cache is still valid (7 days)
        let cacheAge = Date().timeIntervalSince1970 - Double(cachedAt)
        if cacheAge > 7 * 24 * 60 * 60 {
            // Cache expired, delete it
            deleteCachedData(for: url)
            return nil
        }

        return OpenGraphData(
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName,
            url: url.absoluteString
        )
    }

    func cacheData(_ data: OpenGraphData, for url: URL) {
        let insertSQL = """
        INSERT OR REPLACE INTO opengraph_cache (url, title, description, image_url, site_name, cached_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing insert statement")
            return
        }

        defer {
            sqlite3_finalize(statement)
        }

        let urlString = url.absoluteString
        let timestamp = Int64(Date().timeIntervalSince1970)

        sqlite3_bind_text(statement, 1, (urlString as NSString).utf8String, -1, nil)

        if let title = data.title {
            sqlite3_bind_text(statement, 2, (title as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 2)
        }

        if let description = data.description {
            sqlite3_bind_text(statement, 3, (description as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 3)
        }

        if let imageURL = data.imageURL {
            sqlite3_bind_text(statement, 4, (imageURL as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let siteName = data.siteName {
            sqlite3_bind_text(statement, 5, (siteName as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        sqlite3_bind_int64(statement, 6, timestamp)

        if sqlite3_step(statement) != SQLITE_DONE {
            print("Error inserting cache data")
        }
    }

    private func deleteCachedData(for url: URL) {
        let deleteSQL = "DELETE FROM opengraph_cache WHERE url = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        defer {
            sqlite3_finalize(statement)
        }

        let urlString = url.absoluteString
        sqlite3_bind_text(statement, 1, (urlString as NSString).utf8String, -1, nil)
        sqlite3_step(statement)
    }

    func clearExpiredCache() {
        let sevenDaysAgo = Int64(Date().timeIntervalSince1970 - 7 * 24 * 60 * 60)
        let deleteSQL = "DELETE FROM opengraph_cache WHERE cached_at < ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int64(statement, 1, sevenDaysAgo)

        if sqlite3_step(statement) == SQLITE_DONE {
            let deletedCount = sqlite3_changes(db)
            if deletedCount > 0 {
                print("Cleared \(deletedCount) expired cache entries")
            }
        }
    }

    deinit {
        sqlite3_close(db)
    }
}
