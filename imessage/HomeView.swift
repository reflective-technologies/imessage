//
//  HomeView.swift
//  imessage
//
//  Created by hunter diamond on 1/23/26.
//

import SwiftUI

// MARK: - Home View
struct HomeView: View {
    let links: [ExtractedLink]
    @Binding var selectedCategory: LinkCategory
    
    /// Recent links sorted by date (most recent first)
    private var recentLinks: [ExtractedLink] {
        links.sorted { $0.message.date > $1.message.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Recent section at the top
                if !recentLinks.isEmpty {
                    RecentCarouselSection(
                        links: recentLinks,
                        onSeeAll: {
                            selectedCategory = .all
                        }
                    )
                }
                
                // Category sections
                ForEach(LinkCategory.contentCategories) { category in
                    let categoryLinks = linksForCategory(category)
                    if !categoryLinks.isEmpty {
                        CategoryCarouselSection(
                            category: category,
                            links: categoryLinks,
                            onSeeAll: {
                                selectedCategory = category
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func linksForCategory(_ category: LinkCategory) -> [ExtractedLink] {
        links.filter { link in
            LinkCategory.categorize(url: link.url, openGraphData: link.openGraphData) == category
        }
    }
}

// MARK: - Recent Carousel Section
struct RecentCarouselSection: View {
    let links: [ExtractedLink]
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Recent")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(links.prefix(15)) { link in
                        HomeLinkCard(link: link)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Category Carousel Section
struct CategoryCarouselSection: View {
    let category: LinkCategory
    let links: [ExtractedLink]
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
                
                Text(category.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(links.prefix(10)) { link in
                        HomeLinkCard(link: link)
                    }
                }
                .padding(.horizontal, 24)
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

// MARK: - Link Card (Carousel Item)


#Preview {
    HomeView(
        links: [],
        selectedCategory: .constant(.home)
    )
    .frame(width: 800, height: 600)
}
