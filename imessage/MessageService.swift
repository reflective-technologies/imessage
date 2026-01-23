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
                chat.chat_identifier,
                chat.display_name,
                chat.ROWID as chat_rowid,
                (SELECT GROUP_CONCAT(handle.id, ',')
                 FROM chat_handle_join
                 JOIN handle ON chat_handle_join.handle_id = handle.ROWID
                 WHERE chat_handle_join.chat_id = chat.ROWID) as participants,
                message.payload_data
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

            var groupChatName: String?
            if let cString = sqlite3_column_text(statement, 5) {
                groupChatName = String(cString: cString)
            }

            var participants: String?
            if let cString = sqlite3_column_text(statement, 7) {
                participants = String(cString: cString)
            }

            var payloadData: Data?
            if let blob = sqlite3_column_blob(statement, 8) {
                let blobSize = sqlite3_column_bytes(statement, 8)
                payloadData = Data(bytes: blob, count: Int(blobSize))
            }

            // Look up contact name
            let contactName = ContactService.shared.getContactName(
                for: chatIdentifier,
                groupChatName: groupChatName,
                participants: participants
            )

            let message = Message(
                id: id,
                text: text,
                date: date,
                isFromMe: isFromMe,
                chatIdentifier: chatIdentifier,
                contactName: contactName,
                payloadData: payloadData
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

                    // Try to extract cached OpenGraph data from iMessage's payload
                    if let cachedOGData = extractOpenGraphFromPayload(message.payloadData, for: url) {
                        link.openGraphData = cachedOGData
                        print("✅ Loaded cached OpenGraph data for: \(url.absoluteString)")
                    }

                    links.append(link)
                }
            }
        }

        return links
    }

    /// Fetches surrounding messages for context (4 before and 4 after the given message)
    /// Returns messages in chronological order with the target message included
    func fetchSurroundingMessages(for message: Message) throws -> [Message] {
        var messages: [Message] = []
        var db: OpaquePointer?
        
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw MessageServiceError.databaseNotFound
        }
        
        guard FileManager.default.isReadableFile(atPath: dbPath) else {
            throw MessageServiceError.permissionDenied
        }
        
        let result = sqlite3_open(dbPath, &db)
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MessageServiceError.databaseOpenError(errorMessage)
        }
        
        defer {
            sqlite3_close(db)
        }
        
        // Get the chat_id for this message first
        let chatQuery = """
            SELECT chat.ROWID, chat.chat_identifier, chat.display_name,
                   (SELECT GROUP_CONCAT(handle.id, ',')
                    FROM chat_handle_join
                    JOIN handle ON chat_handle_join.handle_id = handle.ROWID
                    WHERE chat_handle_join.chat_id = chat.ROWID) as participants
            FROM chat_message_join
            JOIN chat ON chat_message_join.chat_id = chat.ROWID
            WHERE chat_message_join.message_id = ?
        """
        
        var chatStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, chatQuery, -1, &chatStatement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MessageServiceError.queryError(errorMessage)
        }
        
        sqlite3_bind_int64(chatStatement, 1, Int64(message.id))
        
        var chatId: Int64?
        var chatIdentifier: String?
        var groupChatName: String?
        var participants: String?
        
        if sqlite3_step(chatStatement) == SQLITE_ROW {
            chatId = sqlite3_column_int64(chatStatement, 0)
            if let cString = sqlite3_column_text(chatStatement, 1) {
                chatIdentifier = String(cString: cString)
            }
            if let cString = sqlite3_column_text(chatStatement, 2) {
                groupChatName = String(cString: cString)
            }
            if let cString = sqlite3_column_text(chatStatement, 3) {
                participants = String(cString: cString)
            }
        }
        sqlite3_finalize(chatStatement)
        
        guard let validChatId = chatId else {
            // If no chat found, return just the original message
            return [message]
        }
        
        // Now fetch messages before and after in the same chat
        // We'll use a UNION to get 4 before and 4 after, plus the target message
        let surroundingQuery = """
            SELECT * FROM (
                -- Messages BEFORE (older, smaller dates)
                SELECT
                    message.ROWID,
                    message.text,
                    message.date,
                    message.is_from_me,
                    message.payload_data
                FROM message
                JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
                WHERE chat_message_join.chat_id = ?
                  AND message.date < (SELECT date FROM message WHERE ROWID = ?)
                  AND message.text IS NOT NULL AND message.text != ''
                ORDER BY message.date DESC
                LIMIT 4
            )
            UNION ALL
            SELECT * FROM (
                -- The target message
                SELECT
                    message.ROWID,
                    message.text,
                    message.date,
                    message.is_from_me,
                    message.payload_data
                FROM message
                WHERE message.ROWID = ?
            )
            UNION ALL
            SELECT * FROM (
                -- Messages AFTER (newer, larger dates)
                SELECT
                    message.ROWID,
                    message.text,
                    message.date,
                    message.is_from_me,
                    message.payload_data
                FROM message
                JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
                WHERE chat_message_join.chat_id = ?
                  AND message.date > (SELECT date FROM message WHERE ROWID = ?)
                  AND message.text IS NOT NULL AND message.text != ''
                ORDER BY message.date ASC
                LIMIT 4
            )
            ORDER BY date ASC
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, surroundingQuery, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw MessageServiceError.queryError(errorMessage)
        }
        
        // Bind parameters: chatId, messageId, messageId, chatId, messageId
        sqlite3_bind_int64(statement, 1, validChatId)
        sqlite3_bind_int64(statement, 2, Int64(message.id))
        sqlite3_bind_int64(statement, 3, Int64(message.id))
        sqlite3_bind_int64(statement, 4, validChatId)
        sqlite3_bind_int64(statement, 5, Int64(message.id))
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Look up contact name once
        let contactName = ContactService.shared.getContactName(
            for: chatIdentifier,
            groupChatName: groupChatName,
            participants: participants
        )
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            
            var text: String?
            if let cString = sqlite3_column_text(statement, 1) {
                text = String(cString: cString)
            }
            
            let dateValue = sqlite3_column_int64(statement, 2)
            let date = convertAppleTimestamp(dateValue)
            
            let isFromMe = sqlite3_column_int(statement, 3) == 1
            
            var payloadData: Data?
            if let blob = sqlite3_column_blob(statement, 4) {
                let blobSize = sqlite3_column_bytes(statement, 4)
                payloadData = Data(bytes: blob, count: Int(blobSize))
            }
            
            let msg = Message(
                id: id,
                text: text,
                date: date,
                isFromMe: isFromMe,
                chatIdentifier: chatIdentifier,
                contactName: contactName,
                payloadData: payloadData
            )
            
            messages.append(msg)
        }
        
        // Sort by date to ensure chronological order
        messages.sort { $0.date < $1.date }
        
        return messages
    }

    private func extractOpenGraphFromPayload(_ payloadData: Data?, for url: URL) -> OpenGraphData? {
        guard let data = payloadData else { return nil }

        do {
            // Decode the NSKeyedArchiver plist
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]

            guard let objects = plist?["$objects"] as? [Any] else {
                return nil
            }

            // Find the metadata dictionary that contains title, summary, siteName keys
            var metadataDict: [String: Any]?
            var titleUID: Int?
            var summaryUID: Int?
            var siteNameUID: Int?

            for object in objects {
                if let dict = object as? [String: Any] {
                    if dict.keys.contains("title") && dict.keys.contains("summary") && dict.keys.contains("siteName") {
                        metadataDict = dict

                        // Extract UIDs
                        if let titleRef = dict["title"] as? [String: Any],
                           let uid = titleRef["CF$UID"] as? Int {
                            titleUID = uid
                        }
                        if let summaryRef = dict["summary"] as? [String: Any],
                           let uid = summaryRef["CF$UID"] as? Int {
                            summaryUID = uid
                        }
                        if let siteNameRef = dict["siteName"] as? [String: Any],
                           let uid = siteNameRef["CF$UID"] as? Int {
                            siteNameUID = uid
                        }
                        break
                    }
                }
            }

            // Now extract the actual strings using the UIDs
            var title: String?
            var summary: String?
            var siteName: String?

            if let titleUID = titleUID, titleUID < objects.count {
                title = objects[titleUID] as? String
            }
            if let summaryUID = summaryUID, summaryUID < objects.count {
                summary = objects[summaryUID] as? String
            }
            if let siteNameUID = siteNameUID, siteNameUID < objects.count {
                siteName = objects[siteNameUID] as? String
            }

            // Only return if we found at least a title
            if let title = title, !title.isEmpty {
                return OpenGraphData(
                    title: title,
                    description: summary,
                    imageURL: nil, // We could extract image URL too but it's complex
                    siteName: siteName,
                    url: url.absoluteString
                )
            }

        } catch {
            print("⚠️ Failed to parse payload data: \(error)")
            return nil
        }

        return nil
    }
}
