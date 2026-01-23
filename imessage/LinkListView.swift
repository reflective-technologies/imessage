//
//  LinkListView.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LinkListView: View {
    @State private var links: [ExtractedLink] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showPermissionDenied = false
    @State private var loadedIndices = Set<Int>()
    @State private var currentLoadingBatch = Set<Int>()
    @State private var selectedLink: ExtractedLink?

    var filteredLinks: [ExtractedLink] {
        if searchText.isEmpty {
            return links
        } else {
            return links.filter { link in
                link.displayURL.localizedCaseInsensitiveContains(searchText) ||
                link.message.text?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var groupedLinks: [(date: Date, links: [ExtractedLink])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredLinks) { link in
            calendar.startOfDay(for: link.message.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, links: $0.value) }
    }

    var body: some View {
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
                        }
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
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedLinks, id: \.date) { group in
                                Section {
                                    ForEach(group.links) { link in
                                        LinkRow(
                                            link: link,
                                            isSelected: selectedLink?.id == link.id,
                                            onSelect: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if selectedLink?.id == link.id {
                                                        // Deselect if already selected
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
                                } header: {
                                    DateHeaderView(date: group.date)
                                }
                            }
                        }
                    }
                    .background(Color(hex: "#23282A"))
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
            .frame(minWidth: 400)
            
            // Right side - Message context panel
            if let link = selectedLink {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                MessageContextView(link: link)
                    .frame(minWidth: 350, idealWidth: 400, maxWidth: 500)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .navigationTitle("iMessage Links")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: loadLinks) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            // ToolbarItem(placement: .automatic) {
            //     Button(action: resetPermissions) {
            //         Label("Reset Permissions", systemImage: "xmark.circle")
            //     }
            // }

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
    }

    private func loadLinks() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let messages = try MessageService.shared.fetchAllMessages()
                print("Fetched \(messages.count) messages")

                let extractedLinks = MessageService.shared.extractLinks(from: messages)
                print("Extracted \(extractedLinks.count) links")

                DispatchQueue.main.async {
                    if extractedLinks.isEmpty {
                        if messages.isEmpty {
                            errorMessage = "No messages found in your iMessage database."
                        } else {
                            errorMessage = "No links found in your \(messages.count) recent messages."
                        }
                    } else {
                        self.links = extractedLinks
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

                // Try loading again
                showPermissionDenied = false
                loadLinks()
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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "message.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
            }

            // Title and description
            VStack(spacing: 12) {
                Text("Access Your iMessages")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("Grant access to your Messages folder to view all your shared links in one place.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Error message if present
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Main CTA button
            VStack(spacing: 12) {
                Button(action: onGrantAccess) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("Grant Access to Messages")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 240)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Helper text
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                        Text("You'll select the Messages folder at:")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                    Text("~/Library/Messages")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.separatorColor).opacity(0.2))
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
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
    LinkListView()
}
