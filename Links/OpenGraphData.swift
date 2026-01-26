//
//  OpenGraphData.swift
//  Links
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation

struct OpenGraphData: Codable {
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let url: String?
    let faviconURL: String?

    // Twitter-specific fields (from iMessage cache)
    let twitterAuthorName: String?
    let twitterHandle: String?
    let twitterLikes: String?
    let twitterReplies: String?
    let twitterProfileImageURL: String?

    var hasData: Bool {
        title != nil || description != nil || imageURL != nil
    }

    var isTwitter: Bool {
        twitterHandle != nil || siteName == "X (formerly Twitter)"
    }

    // Convenience initializer for non-Twitter content
    init(title: String?, description: String?, imageURL: String?, siteName: String?, url: String?, faviconURL: String? = nil) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.siteName = siteName
        self.url = url
        self.faviconURL = faviconURL
        self.twitterAuthorName = nil
        self.twitterHandle = nil
        self.twitterLikes = nil
        self.twitterReplies = nil
        self.twitterProfileImageURL = nil
    }

    // Full initializer with Twitter fields
    init(title: String?, description: String?, imageURL: String?, siteName: String?, url: String?, faviconURL: String? = nil,
         twitterAuthorName: String?, twitterHandle: String?, twitterLikes: String?, twitterReplies: String?, twitterProfileImageURL: String?) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.siteName = siteName
        self.url = url
        self.faviconURL = faviconURL
        self.twitterAuthorName = twitterAuthorName
        self.twitterHandle = twitterHandle
        self.twitterLikes = twitterLikes
        self.twitterReplies = twitterReplies
        self.twitterProfileImageURL = twitterProfileImageURL
    }
}
