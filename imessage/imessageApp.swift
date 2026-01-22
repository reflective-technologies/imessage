//
//  imessageApp.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import SwiftUI

@main
struct imessageApp: App {
    init() {
        // Clean up expired cache entries on app launch
        OpenGraphCacheService.shared.clearExpiredCache()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Help") {
                    if let url = URL(string: "https://support.apple.com/guide/mac-help/control-access-to-files-and-folders-on-mac-mchld5a35146/mac") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
