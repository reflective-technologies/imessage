//
//  LinkListView.swift
//  Links
//
//  Created by hunter diamond on 1/22/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
internal import Contacts

// MARK: - Link Category
enum LinkCategory: String, CaseIterable, Identifiable {
    case home = "Home"
    case all = "All"
    case articles = "Articles"
    case videos = "Videos"
    case social = "Social"
    case shopping = "Shopping"
    case music = "Music"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .all: return "link"
        case .articles: return "doc.text"
        case .videos: return "play.rectangle"
        case .social: return "bubble.left.and.bubble.right"
        case .shopping: return "cart"
        case .music: return "music.note"
        case .other: return "archivebox"
        }
    }
    
    /// Categories that represent actual link types (excludes home and all)
    static var contentCategories: [LinkCategory] {
        [.articles, .videos, .social, .shopping, .music, .other]
    }
    
    /// Categories shown in the sidebar (excludes all)
    static var sidebarCategories: [LinkCategory] {
        [.home, .articles, .videos, .social, .shopping, .music, .other]
    }
    
    static func categorize(url: URL, openGraphData: OpenGraphData?) -> LinkCategory {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        // Video platforms
        let videoHosts = ["youtube.com", "youtu.be", "vimeo.com", "twitch.tv", "tiktok.com", 
                         "dailymotion.com", "wistia.com", "loom.com"]
        if videoHosts.contains(where: { host.contains($0) }) {
            return .videos
        }
        
        // Social media
        let socialHosts = ["twitter.com", "x.com", "facebook.com", "instagram.com", "linkedin.com",
                          "reddit.com", "threads.net", "mastodon.social", "bsky.app", "snapchat.com"]
        if socialHosts.contains(where: { host.contains($0) }) {
            return .social
        }
        
        // Shopping
        let shoppingHosts = ["amazon.com", "ebay.com", "etsy.com", "shopify.com", "walmart.com",
                            "target.com", "bestbuy.com", "aliexpress.com", "wish.com", "shop.app"]
        if shoppingHosts.contains(where: { host.contains($0) }) {
            return .shopping
        }
        
        // Music platforms
        let musicHosts = ["soundcloud.com", "bandcamp.com", "spotify.com", "open.spotify.com",
                         "music.apple.com", "itunes.apple.com", "tidal.com", "deezer.com",
                         "audiomack.com", "mixcloud.com", "last.fm", "pandora.com",
                         "music.youtube.com", "music.amazon.com"]
        if musicHosts.contains(where: { host.contains($0) }) {
            return .music
        }
        
        // Articles - news sites and blogs
        let articleHosts = ["medium.com", "substack.com", "nytimes.com", "wsj.com", "bbc.com",
                           "cnn.com", "theguardian.com", "techcrunch.com", "theverge.com",
                           "arstechnica.com", "wired.com", "forbes.com", "bloomberg.com",
                           "reuters.com", "apnews.com", "npr.org", "washingtonpost.com",
                           "huffpost.com", "buzzfeed.com", "vice.com", "vox.com"]
        if articleHosts.contains(where: { host.contains($0) }) {
            return .articles
        }
        
        // Check OpenGraph data for clues
        if let ogData = openGraphData {
            let title = ogData.title?.lowercased() ?? ""
            let description = ogData.description?.lowercased() ?? ""
            
            // Video indicators
            if title.contains("video") || description.contains("watch") {
                return .videos
            }
        }
        
        // Check path for article indicators
        let articlePaths = ["/article", "/post", "/blog", "/news", "/story"]
        if articlePaths.contains(where: { path.contains($0) }) {
            return .articles
        }
        
        return .other
    }
}

// MARK: - Grouping Mode
enum GroupingMode: String, CaseIterable, Identifiable {
    case date = "Date"
    case domain = "Domain"
    case contact = "Contact"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .date: return "calendar"
        case .domain: return "globe"
        case .contact: return "person"
        }
    }
}

struct LinkListView: View {
    @Binding var selectedCategory: LinkCategory
    @State private var links: [ExtractedLink] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showPermissionDenied = false
    @State private var messagesAccessGranted = false
    @State private var loadedIndices = Set<Int>()
    @State private var currentLoadingBatch = Set<Int>()
    @State private var selectedLink: ExtractedLink?
    @State private var groupingMode: GroupingMode = .date
    @State private var canShowMessagePanel = true
    @ObservedObject private var viewModeStore = ViewModeStore.shared

    var filteredLinks: [ExtractedLink] {
        var result = links
        
        // Filter by category (home and all show everything)
        if selectedCategory != .home {
            result = result.filter { link in
                LinkCategory.categorize(url: link.url, openGraphData: link.openGraphData) == selectedCategory
            }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { link in
                // Search in URL
                link.url.absoluteString.lowercased().contains(query) ||
                // Search in host/domain
                (link.url.host?.lowercased().contains(query) ?? false) ||
                // Search in OpenGraph title
                (link.openGraphData?.title?.lowercased().contains(query) ?? false) ||
                // Search in OpenGraph description
                (link.openGraphData?.description?.lowercased().contains(query) ?? false) ||
                // Search in OpenGraph site name
                (link.openGraphData?.siteName?.lowercased().contains(query) ?? false) ||
                // Search in contact name
                link.displayContactName.lowercased().contains(query) ||
                // Search in message text
                (link.message.text?.lowercased().contains(query) ?? false)
            }
        }
        
        return result
    }
    
    var groupedByDate: [(key: Date, links: [ExtractedLink])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredLinks) { link in
            calendar.startOfDay(for: link.message.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { (key: $0.key, links: $0.value) }
    }
    
    var groupedByDomain: [(key: String, links: [ExtractedLink])] {
        let grouped = Dictionary(grouping: filteredLinks) { link in
            link.url.host?.replacingOccurrences(of: "www.", with: "") ?? "Unknown"
        }
        return grouped.sorted { $0.value.count > $1.value.count }.map { (key: $0.key, links: $0.value) }
    }
    
    var groupedByContact: [(key: String, links: [ExtractedLink])] {
        let grouped = Dictionary(grouping: filteredLinks) { link in
            link.displayContactName
        }
        return grouped.sorted { $0.value.count > $1.value.count }.map { (key: $0.key, links: $0.value) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Need at least 400 for link list + 300 for message panel = 700 total
            let canShow = geometry.size.width >= 700
            let isCompact = geometry.size.width < 700
            
            HStack(spacing: 0) {
                // Left side - Link list
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView("Loading messages...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if showPermissionDenied {
                        OnboardingView(
                            errorMessage: errorMessage,
                            onGrantAccess: {
                                selectDatabaseFile()
                            },
                            onContinue: {
                                showPermissionDenied = false
                                loadLinks()
                            },
                            messagesGranted: $messagesAccessGranted
                        )
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                                .padding()
                            Button("Retry") {
                                loadLinks()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if selectedCategory == .home {
                        // Home view with carousels
                        HomeView(
                            links: links,
                            selectedCategory: $selectedCategory,
                            selectedLink: $selectedLink,
                            canShowMessagePanel: canShowMessagePanel
                        )
                    } else {
                        VStack(spacing: 0) {
                            if viewModeStore.viewMode == .grid {
                                // Grid view using HomeLinkCard
                                ScrollView {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 280), spacing: 12)], spacing: 12) {
                                        ForEach(filteredLinks) { link in
                                            HomeLinkCard(
                                                link: link,
                                                isSelected: selectedLink?.id == link.id,
                                                onSelect: {
                                                    if canShowMessagePanel {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            selectedLink = selectedLink?.id == link.id ? nil : link
                                                        }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .padding(16)
                                }
                                .background(Color(nsColor: .windowBackgroundColor))
                            } else {
                                // List view
                                ScrollView {
                                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                        switch groupingMode {
                                        case .date:
                                            ForEach(groupedByDate, id: \.key) { group in
                                                Section {
                                                    ForEach(group.links) { link in
                                                        linkRow(for: link, canShowMessagePanel: canShowMessagePanel)
                                                    }
                                                } header: {
                                                    DateHeaderView(date: group.key)
                                                }
                                            }
                                        case .domain:
                                            ForEach(groupedByDomain, id: \.key) { group in
                                                Section {
                                                    ForEach(group.links) { link in
                                                        linkRow(for: link, canShowMessagePanel: canShowMessagePanel)
                                                    }
                                                } header: {
                                                    GroupHeaderView(title: group.key, count: group.links.count, icon: "globe")
                                                }
                                            }
                                        case .contact:
                                            ForEach(groupedByContact, id: \.key) { group in
                                                Section {
                                                    ForEach(group.links) { link in
                                                        linkRow(for: link, canShowMessagePanel: canShowMessagePanel)
                                                    }
                                                } header: {
                                                    GroupHeaderView(title: group.key, count: group.links.count, icon: "person.fill")
                                                }
                                            }
                                        }
                                    }
                                }
                                .background(Color(hex: "#23282A"))
                            }
                        }
                        .searchable(text: $searchText, prompt: "Search links or messages")
                        .overlay {
                            if filteredLinks.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: searchText.isEmpty ? "link.circle" : "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text(searchText.isEmpty ? "No links found in messages" : "No matching links")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: isCompact ? nil : 400)
                
                // Right side - Message context panel (only show when there's enough room)
                if canShow, let link = selectedLink {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    MessageContextView(link: link)
                        .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .onChange(of: canShow) { _, newValue in
                canShowMessagePanel = newValue
                // Clear selection when panel can no longer be shown
                if !newValue && selectedLink != nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedLink = nil
                    }
                }
            }
            .onAppear {
                canShowMessagePanel = canShow
            }
        }
        .navigationTitle(selectedCategory.rawValue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // View mode toggle (grid/list)
                Picker("View", selection: $viewModeStore.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            
            ToolbarItem(placement: .primaryAction) {
                if canShowMessagePanel && selectedLink != nil {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedLink = nil
                        }
                    }) {
                        Image(systemName: "xmark")
                    }
                    .help("Close Context")
                }
            }
        }
        .onAppear {
            if links.isEmpty {
                // Try to restore security-scoped bookmark
                var bookmarkRestored = false
                if let bookmarkData = UserDefaults.standard.data(forKey: "databaseBookmark") {
                    do {
                        var isStale = false
                        let folderURL = try URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        )

                        if !isStale {
                            let dbURL = folderURL.appendingPathComponent("chat.db")

                            // Verify this is actually a valid Messages folder
                            if FileManager.default.fileExists(atPath: dbURL.path) {
                                MessageService.shared.setDatabaseURL(dbURL, folderURL: folderURL)
                                bookmarkRestored = true
                                print("Successfully restored bookmark for: \(dbURL.path)")
                            } else {
                                print("Bookmark points to invalid location: \(dbURL.path)")
                                // Clear the bad bookmark
                                UserDefaults.standard.removeObject(forKey: "databaseBookmark")
                            }
                        }
                    } catch {
                        print("Failed to resolve bookmark: \(error)")
                        // Clear the bad bookmark
                        UserDefaults.standard.removeObject(forKey: "databaseBookmark")
                    }
                }

                // If we couldn't restore a bookmark, show onboarding
                if !bookmarkRestored {
                    DispatchQueue.main.async {
                        showPermissionDenied = true
                        errorMessage = nil  // Don't show error on first launch
                    }
                } else {
                    loadLinks()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidLoad)) { _ in
            if !links.isEmpty {
                loadLinks()
            }
        }
    }
    
    @ViewBuilder
    private func linkRow(for link: ExtractedLink, canShowMessagePanel: Bool) -> some View {
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
        .onAppear {
            if let index = filteredLinks.firstIndex(where: { $0.id == link.id }) {
                loadOpenGraphIfNeeded(for: link, at: index)
            }
        }
    }

    private func loadLinks() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let messages = try MessageService.shared.fetchAllMessages()
                print("Fetched \(messages.count) messages")

                let allExtractedLinks = MessageService.shared.extractLinks(from: messages)
                // Filter out links from messages sent by the user ("Me")
                let extractedLinks = allExtractedLinks.filter { !$0.message.isFromMe }
                print("Extracted \(allExtractedLinks.count) links, showing \(extractedLinks.count) after filtering out sent messages")

                DispatchQueue.main.async {
                    if extractedLinks.isEmpty {
                        if messages.isEmpty {
                            errorMessage = "No messages found in your iMessage database."
                        } else {
                            errorMessage = "No links found in your \(messages.count) recent messages."
                        }
                    } else {
                        self.links = extractedLinks
                        // Update shared store for sidebar counts
                        LinkStore.shared.updateLinks(extractedLinks)
                    }
                    isLoading = false
                }
            } catch MessageServiceError.databaseNotFound {
                DispatchQueue.main.async {
                    errorMessage = "iMessage database not found. Make sure Messages app is set up on this Mac."
                    isLoading = false
                }
            } catch MessageServiceError.permissionDenied {
                DispatchQueue.main.async {
                    errorMessage = "Permission denied accessing iMessage database."
                    showPermissionDenied = true
                    isLoading = false
                }
            } catch MessageServiceError.databaseOpenError(let error) {
                DispatchQueue.main.async {
                    errorMessage = "Database error: \(error)\n\nCheck Console.app for detailed logs."
                    isLoading = false
                }
            } catch MessageServiceError.queryError(let error) {
                DispatchQueue.main.async {
                    errorMessage = "Query error: \(error)\n\nCheck Console.app for detailed logs."
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Unexpected error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func selectDatabaseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsOtherFileTypes = true
        panel.message = "Select the Messages folder to grant access"
        panel.prompt = "Grant Access"

        // Set the default directory to ~/Library/Messages
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let messagesDir = homeDir.appendingPathComponent("Library/Messages")
        panel.directoryURL = messagesDir

        // If Messages folder doesn't exist, fall back to Library
        if !FileManager.default.fileExists(atPath: messagesDir.path) {
            let libraryDir = homeDir.appendingPathComponent("Library")
            panel.directoryURL = libraryDir
        }

        panel.begin { response in
            if response == .OK, let selectedURL = panel.url {
                // Determine the actual folder and database URLs
                var folderURL: URL
                var dbURL: URL

                // Check if user selected chat.db file or Messages folder
                if selectedURL.lastPathComponent == "chat.db" {
                    // User selected the file, use its parent as the folder
                    folderURL = selectedURL.deletingLastPathComponent()
                    dbURL = selectedURL
                } else {
                    // User selected the Messages folder
                    folderURL = selectedURL
                    dbURL = selectedURL.appendingPathComponent("chat.db")
                }

                print("Selected URL: \(selectedURL.path)")
                print("Folder URL: \(folderURL.path)")
                print("Database URL: \(dbURL.path)")

                // Store bookmark for future access
                do {
                    let bookmarkData = try folderURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(bookmarkData, forKey: "databaseBookmark")
                } catch {
                    print("Failed to create bookmark: \(error)")
                }

                // Update the service with the new URL (this will start security-scoped access)
                MessageService.shared.setDatabaseURL(dbURL, folderURL: folderURL)

                // Mark messages access as granted, but stay on onboarding
                messagesAccessGranted = true
            }
        }
    }

    private func resetPermissions() {
        // Clear the bookmark
        UserDefaults.standard.removeObject(forKey: "databaseBookmark")

        // Reset state
        links = []
        errorMessage = nil
        showPermissionDenied = true
        isLoading = false
        loadedIndices.removeAll()
        currentLoadingBatch.removeAll()

        print("Permissions reset - returning to onboarding")
    }

    private func loadOpenGraphIfNeeded(for link: ExtractedLink, at index: Int) {
        // Only load if not already loaded and not currently loading
        guard !loadedIndices.contains(index),
              !currentLoadingBatch.contains(index) else {
            return
        }

        // Check if we should load based on batch size
        let activeLoads = currentLoadingBatch.count
        guard activeLoads < 20 else {
            return
        }

        // Mark as loading
        currentLoadingBatch.insert(index)

        // Load the OpenGraph data
        link.loadOpenGraphData()

        // After a short delay, mark as loaded and remove from current batch
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                loadedIndices.insert(index)
                currentLoadingBatch.remove(index)
            }
        }
    }
}


// MARK: - Group Header View (for domain/contact grouping)
struct GroupHeaderView: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
            Text("(\(count))")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#23282A"))
    }
}

// MARK: - Date Header View
struct DateHeaderView: View {
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
        HStack {
            Text(displayText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#23282A"))
    }
}

struct OnboardingView: View {
    let errorMessage: String?
    let onGrantAccess: () -> Void
    let onContinue: () -> Void
    @Binding var messagesGranted: Bool
    
    @State private var contactsGranted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Title
                Text("Connect iMessage")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Permission rows
                VStack(spacing: 16) {
                    // Messages permission
                    PermissionRow(
                        icon: "externaldrive.fill",
                        title: "Messages",
                        description: "Allows this app to read your iMessages locally.",
                        isGranted: messagesGranted,
                        onRequest: onGrantAccess
                    )
                    
                    // Contacts permission
                    PermissionRow(
                        icon: "person.2.fill",
                        title: "Contacts",
                        description: "Allows this app to show who sent you links.",
                        isGranted: contactsGranted,
                        onRequest: {
                            ContactService.shared.requestAccess { granted in
                                contactsGranted = granted
                            }
                        }
                    )
                }
                
                // Privacy notice
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("Your messages stay on your device")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Text("This app process all data locally and does not provide access to any third parties.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .padding(.top, 8)
                
                // Continue button (only when messages granted)
                if messagesGranted {
                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                
                // Error message if present
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(Color(hex: "#23282A"))
            .cornerRadius(16)
            .frame(maxWidth: 460)
            
            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            // Check current permission states
            contactsGranted = ContactService.shared.authorizationStatus == .authorized
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Request button
            if !isGranted {
                Button(action: onRequest) {
                    Text("Request...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.separatorColor).opacity(0.3))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct OpenGraphPreviewCard: View {
    let ogData: OpenGraphData
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image preview - full width at top
            if let imageURLString = ogData.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color(.separatorColor).opacity(0.1)
                            ProgressView()
                        }
                        .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        ZStack {
                            Color(.separatorColor).opacity(0.1)
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Text content below image
            VStack(alignment: .leading, spacing: 8) {
                if let title = ogData.title {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                if let description = ogData.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    if let siteName = ogData.siteName {
                        Text(siteName.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    } else if let host = url.host {
                        Text(host.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

struct LinkPreviewPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Placeholder image
            ZStack {
                Color(.separatorColor).opacity(0.1)
                ProgressView()
            }
            .frame(height: 200)

            // Placeholder text
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color(.separatorColor).opacity(0.2))
                    .frame(height: 18)
                    .cornerRadius(4)

                Rectangle()
                    .fill(Color(.separatorColor).opacity(0.15))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(4)

                Rectangle()
                    .fill(Color(.separatorColor).opacity(0.1))
                    .frame(width: 120, height: 12)
                    .cornerRadius(4)
            }
            .padding(16)
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

struct SimpleLinkView: View {
    let link: ExtractedLink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon and URL display
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: "link")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let host = link.url.host {
                        Text(host.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Text(link.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(link.displayURL)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .padding(16)
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    @Previewable @State var category: LinkCategory = .home
    LinkListView(selectedCategory: $category)
}
