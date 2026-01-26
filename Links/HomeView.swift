//
//  HomeView.swift
//  Links
//
//  Created by hunter diamond on 1/23/26.
//

import SwiftUI
internal import Contacts

// MARK: - Home View
struct HomeView: View {
    let links: [ExtractedLink]
    @Binding var selectedCategory: LinkCategory
    @Binding var selectedLink: ExtractedLink?
    let canShowMessagePanel: Bool
    @State private var hasContactsAccess: Bool = ContactService.shared.hasAccess
    @ObservedObject private var viewModeStore = ViewModeStore.shared
    
    /// Recent links sorted by date (most recent first)
    private var recentLinks: [ExtractedLink] {
        links.sorted { $0.message.date > $1.message.date }
    }
    
    var body: some View {
        Group {
            if viewModeStore.viewMode == .grid {
                // Card carousel view
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Contacts permission banner (if not authorized)
                        if !hasContactsAccess {
                            ContactsPermissionBanner(
                                status: ContactService.shared.authorizationStatus,
                                onRequestAccess: {
                                    ContactService.shared.requestAccess { granted in
                                        hasContactsAccess = ContactService.shared.hasAccess
                                    }
                                }
                            )
                            .padding(.horizontal, 24)
                        }
                        
                        // Recent section at the top
                        if !recentLinks.isEmpty {
                            RecentCarouselSection(
                                links: recentLinks,
                                selectedLink: $selectedLink,
                                canShowMessagePanel: canShowMessagePanel,
                                onSeeAll: {
                                    viewModeStore.viewMode = .list
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
                                    selectedLink: $selectedLink,
                                    canShowMessagePanel: canShowMessagePanel,
                                    onSeeAll: {
                                        selectedCategory = category
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 24)
                }
            } else {
                // List view - show all links with date grouping
                HomeListView(
                    links: recentLinks,
                    hasContactsAccess: $hasContactsAccess,
                    selectedLink: $selectedLink,
                    canShowMessagePanel: canShowMessagePanel
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Refresh contacts authorization status when view appears
            hasContactsAccess = ContactService.shared.hasAccess
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidLoad)) { _ in
            // Update when contacts finish loading (means permission was granted)
            hasContactsAccess = ContactService.shared.hasAccess
        }
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
    @Binding var selectedLink: ExtractedLink?
    let canShowMessagePanel: Bool
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
                        HomeLinkCard(
                            link: link,
                            isSelected: canShowMessagePanel && selectedLink?.id == link.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedLink?.id == link.id {
                                        selectedLink = nil
                                    } else {
                                        selectedLink = link
                                    }
                                }
                            }
                        )
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
    @Binding var selectedLink: ExtractedLink?
    let canShowMessagePanel: Bool
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
                        HomeLinkCard(
                            link: link,
                            isSelected: canShowMessagePanel && selectedLink?.id == link.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedLink?.id == link.id {
                                        selectedLink = nil
                                    } else {
                                        selectedLink = link
                                    }
                                }
                            }
                        )
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

// MARK: - Home List View (All links in list format)
struct HomeListView: View {
    let links: [ExtractedLink]
    @Binding var hasContactsAccess: Bool
    @Binding var selectedLink: ExtractedLink?
    let canShowMessagePanel: Bool
    
    private var groupedByDate: [(key: Date, links: [ExtractedLink])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: links) { link in
            calendar.startOfDay(for: link.message.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { (key: $0.key, links: $0.value) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Contacts permission banner (if not authorized)
                if !hasContactsAccess {
                    ContactsPermissionBanner(
                        status: ContactService.shared.authorizationStatus,
                        onRequestAccess: {
                            ContactService.shared.requestAccess { granted in
                                hasContactsAccess = ContactService.shared.hasAccess
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedByDate, id: \.key) { group in
                        Section {
                            ForEach(group.links) { link in
                                LinkRow(
                                    link: link,
                                    isSelected: canShowMessagePanel && selectedLink?.id == link.id,
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedLink?.id == link.id {
                                                selectedLink = nil
                                            } else {
                                                selectedLink = link
                                            }
                                        }
                                    }
                                )
                            }
                        } header: {
                            HomeDateHeaderView(date: group.key)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .coordinateSpace(name: "scroll")
        .background(Color(hex: "#23282A"))
    }
}

// MARK: - Home Date Header View
struct HomeDateHeaderView: View {
    let date: Date
    
    private var displayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            // This week - show day name
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            // This year - show month and day
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date)
        } else {
            // Different year - show full date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .named("scroll")).minY
            // Header is considered "pinned" when it's at or near the top
            let isPinned = minY <= 1
            
            HStack {
                Text(displayText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isPinned ? .white : .gray)
                    .padding(.horizontal, isPinned ? 14 : 0)
                    .padding(.vertical, isPinned ? 7 : 0)
                    .background {
                        if isPinned {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.3),
                                                    .white.opacity(0.1),
                                                    .clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                    }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isPinned ? 10 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(isPinned ? Color.clear : Color(hex: "#23282A"))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPinned)
        }
        .frame(height: 40)
    }
}

// MARK: - Contacts Permission Banner
struct ContactsPermissionBanner: View {
    let status: CNAuthorizationStatus
    let onRequestAccess: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Enable Contacts")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(status == .denied ? "Open System Settings to enable access" : "See who sent you each link")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action button
            if status == .denied {
                Button(action: {
                    // Open System Settings to Privacy & Security > Contacts
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onRequestAccess) {
                    Text("Enable")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView(
        links: [],
        selectedCategory: .constant(.home),
        selectedLink: .constant(nil),
        canShowMessagePanel: true
    )
    .frame(width: 800, height: 600)
}
