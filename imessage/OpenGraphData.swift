//
//  OpenGraphData.swift
//  imessage
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

    var hasData: Bool {
        title != nil || description != nil || imageURL != nil
    }
}
