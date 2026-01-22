//
//  Models.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation

struct Message: Identifiable {
    let id: Int
    let text: String?
    let date: Date
    let isFromMe: Bool
    let chatIdentifier: String?
    let contactName: String?
}

struct ExtractedLink: Identifiable {
    let id = UUID()
    let url: URL
    let message: Message

    var displayTitle: String {
        url.host ?? url.absoluteString
    }

    var displayURL: String {
        url.absoluteString
    }

    var displayContactName: String {
        if let contactName = message.contactName {
            return contactName
        } else if let chatId = message.chatIdentifier {
            return chatId
        } else {
            return "Unknown"
        }
    }
}
