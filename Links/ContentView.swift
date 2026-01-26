//
//  ContentView.swift
//  Links
//
//  Created by hunter diamond on 1/22/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var selectedCategory: LinkCategory = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedCategory: $selectedCategory)
        } detail: {
            LinkListView(selectedCategory: $selectedCategory)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedCategory: LinkCategory
    @StateObject private var linkStore = LinkStore.shared
    
    var body: some View {
        List(selection: $selectedCategory) {
            Section {
                ForEach(LinkCategory.sidebarCategories) { category in
                    SidebarRow(
                        category: category,
                        count: linkStore.countForCategory(category),
                        isSelected: selectedCategory == category
                    )
                    .tag(category)
                }
            } header: {
                Text("Categories")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Links")
        .frame(minWidth: 180)
    }
}

// MARK: - Sidebar Row
struct SidebarRow: View {
    let category: LinkCategory
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Label {
                Text(category.rawValue)
            } icon: {
                Image(systemName: category.icon)
                    .foregroundColor(isSelected ? .white : categoryColor)
            }
            
            Spacer()
            
            if count > 0 && category != .home {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case .home: return .blue
        case .all: return .blue
        case .articles: return .orange
        case .videos: return .red
        case .social: return .purple
        case .shopping: return .green
        case .music: return .pink
        case .other: return .gray
        }
    }
}

// MARK: - Link Store (Shared state for sidebar counts)
class LinkStore: ObservableObject {
    static let shared = LinkStore()
    
    @Published var links: [ExtractedLink] = []
    
    func countForCategory(_ category: LinkCategory) -> Int {
        if category == .home {
            return links.count
        }
        return links.filter { link in
            LinkCategory.categorize(url: link.url, openGraphData: link.openGraphData) == category
        }.count
    }
    
    func updateLinks(_ newLinks: [ExtractedLink]) {
        DispatchQueue.main.async {
            self.links = newLinks
        }
    }
}

#Preview {
    ContentView()
}
