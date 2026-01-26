//
//  Models.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
import SwiftUI
import Combine

struct Message: Identifiable {
    let id: Int
    let text: String?
    let date: Date
    let isFromMe: Bool
    let chatIdentifier: String?
    let contactName: String?  // For the overall chat/conversation name
    let payloadData: Data?
    let senderIdentifier: String?  // The individual sender's handle (phone/email) for group chats
    let senderName: String?  // Resolved contact name for the individual sender
    
    /// Whether this message is from a group chat
    var isGroupChat: Bool {
        chatIdentifier?.hasPrefix("chat") ?? false
    }
    
    /// Display name for the sender of this specific message
    var senderDisplayName: String {
        if isFromMe {
            return "Me"
        }
        return senderName ?? senderIdentifier ?? contactName ?? "Unknown"
    }
    
    /// Get the sender's photo data
    var senderPhoto: Data? {
        if isFromMe {
            return nil
        }
        return ContactService.shared.getContactPhoto(for: senderIdentifier)
    }
}

class ExtractedLink: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let message: Message
    @Published var openGraphData: OpenGraphData?
    @Published var isLoadingOpenGraph = false

    init(url: URL, message: Message) {
        self.url = url
        self.message = message
    }

    var displayTitle: String {
        openGraphData?.title ?? url.host ?? url.absoluteString
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
    
    var contactPhoto: Data? {
        ContactService.shared.getContactPhoto(for: message.chatIdentifier)
    }

    func loadOpenGraphData() {
        guard openGraphData == nil, !isLoadingOpenGraph else { return }

        isLoadingOpenGraph = true

        Task {
            let data = await OpenGraphService.shared.fetchMetadata(for: url)
            await MainActor.run {
                self.openGraphData = data
                self.isLoadingOpenGraph = false
            }
        }
    }
}
