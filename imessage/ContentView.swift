//
//  ContentView.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: LinkListView()) {
                    Label("All Links", systemImage: "link.circle")
                }
            }
            .navigationTitle("iMessage")
        } detail: {
            LinkListView()
        }
    }
}

#Preview {
    ContentView()
}
