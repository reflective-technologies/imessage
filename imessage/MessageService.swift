//
//  MessageService.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
import SQLite3

enum MessageServiceError: Error {
    case databaseNotFound
    case databaseOpenError(String)
    case queryError(String)
    case permissionDenied
    case noSecurityScopedAccess
}

class MessageService {
    static let shared = MessageService()

    private var dbPath: String
    private var securityScopedURL: URL?
    private var folderURL: URL?
    private var isAccessingFolder = false

    private init() {
        // Use NSHomeDirectory() for more reliable path expansion
        let homeDir = NSHomeDirectory()
        dbPath = "\(homeDir)/Library/Messages/chat.db"
        print("Initialized MessageService with path: \(dbPath)")
    }

    func setDatabaseURL(_ url: URL, folderURL: URL) {
        // Stop any existing access
        if isAccessingFolder, let folder = self.folderURL {
            folder.stopAccessingSecurityScopedResource()
            isAccessingFolder = false
        }

        // Store the folder and database URLs
        self.folderURL = folderURL
        self.securityScopedURL = url
        self.dbPath = url.path

        // Start accessing the folder and keep it alive
        if folderURL.startAccessingSecurityScopedResource() {
            isAccessingFolder = true
            print("Started security-scoped access to folder: \(folderURL.path)")
        }

        print("Updated database path to: \(dbPath)")
    }

    func fetchAllMessages() throws -> [Message] {
        var messages: [Message] = []
        var db: OpaquePointer?

        print("Database path: \(dbPath)")
        print("Has folder access: \(isAccessingFolder)")

        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("Database file does not exist at path")
            throw MessageServiceError.databaseNotFound
        }

        guard FileManager.default.isReadableFile(atPath: dbPath) else {
            print("Database file is not readable - permission denied")
            throw MessageServiceError.permissionDenied
        }

        let result = sqlite3_open(dbPath, &db)
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Error opening database: \(errorMessage)")
            throw MessageServiceError.databaseOpenError(errorMessage)
        }

        defer {
            sqlite3_close(db)
        }

        let query = """
            SELECT
                message.ROWID,
                message.text,
                message.date,
                message.is_from_me,
                chat.chat_identifier
            FROM message
            LEFT JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
            LEFT JOIN chat ON chat_message_join.chat_id = chat.ROWID
            WHERE message.text IS NOT NULL AND message.text != ''
            ORDER BY message.date DESC
            LIMIT 10000
        """

        var statement: OpaquePointer?

        let prepareResult = sqlite3_prepare_v2(db, query, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Error preparing statement: \(errorMessage)")
            throw MessageServiceError.queryError(errorMessage)
        }

        defer {
            sqlite3_finalize(statement)
        }

        var rowCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))

            var text: String?
            if let cString = sqlite3_column_text(statement, 1) {
                text = String(cString: cString)
            }

            let dateValue = sqlite3_column_int64(statement, 2)
            let date = convertAppleTimestamp(dateValue)

            let isFromMe = sqlite3_column_int(statement, 3) == 1

            var chatIdentifier: String?
            if let cString = sqlite3_column_text(statement, 4) {
                chatIdentifier = String(cString: cString)
            }

            // Look up contact name
            let contactName = ContactService.shared.getContactName(for: chatIdentifier)

            let message = Message(
                id: id,
                text: text,
                date: date,
                isFromMe: isFromMe,
                chatIdentifier: chatIdentifier,
                contactName: contactName
            )

            messages.append(message)
            rowCount += 1
        }

        print("Successfully fetched \(rowCount) messages with text")
        return messages
    }

    private func convertAppleTimestamp(_ timestamp: Int64) -> Date {
        let appleEpoch = Date(timeIntervalSinceReferenceDate: 0)
        let seconds = Double(timestamp) / 1_000_000_000.0
        return appleEpoch.addingTimeInterval(seconds)
    }

    func extractLinks(from messages: [Message]) -> [ExtractedLink] {
        var links: [ExtractedLink] = []

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        for message in messages {
            guard let text = message.text else { continue }

            let nsString = text as NSString
            let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches ?? [] {
                if let url = match.url {
                    let link = ExtractedLink(url: url, message: message)
                    links.append(link)
                }
            }
        }

        return links
    }
}
