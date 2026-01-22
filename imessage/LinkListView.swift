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

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()

                    if showPermissionDenied {
                        Text("Grant access to your Messages folder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Select Messages Folder") {
                            selectDatabaseFile()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("Select the folder at:\n~/Library/Messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    } else {
                        Button("Retry") {
                            loadLinks()
                        }
                    }
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(Array(filteredLinks.enumerated()), id: \.element.id) { index, link in
                            LinkRow(link: link)
                                .padding(.horizontal, 12)
                                .onAppear {
                                    loadOpenGraphIfNeeded(for: link, at: index)
                                }
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(.windowBackgroundColor))
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
        .navigationTitle("iMessage Links")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: loadLinks) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            ToolbarItem(placement: .status) {
                if !isLoading && errorMessage == nil {
                    Text("\(filteredLinks.count) links")
                        .foregroundColor(.secondary)
                        .font(.caption)
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

                // If we couldn't restore a bookmark, show the file picker immediately
                if !bookmarkRestored {
                    DispatchQueue.main.async {
                        showPermissionDenied = true
                        errorMessage = "No access to iMessage database yet."
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
        panel.message = "Select the Messages folder or chat.db file\n(~/Library/Messages)"
        panel.prompt = "Grant Access"

        // Set the default directory to ~/Library
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let libraryDir = homeDir.appendingPathComponent("Library")
        panel.directoryURL = libraryDir

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
