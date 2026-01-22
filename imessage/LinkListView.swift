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
                List {
                    ForEach(filteredLinks) { link in
                        LinkRowView(link: link)
                            .padding(.vertical, 4)
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
}

struct LinkRowView: View {
    let link: ExtractedLink

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.displayTitle)
                        .font(.headline)

                    Text(link.displayURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    NSWorkspace.shared.open(link.url)
                }) {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help("Open link")
            }

            if let messageText = link.message.text {
                Text(messageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 24)
            }

            HStack {
                Image(systemName: link.message.isFromMe ? "person.fill" : "person")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(link.displayContactName)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(link.message.date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 24)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.displayURL, forType: .string)
            }) {
                Label("Copy Link", systemImage: "doc.on.doc")
            }

            Button(action: {
                NSWorkspace.shared.open(link.url)
            }) {
                Label("Open in Browser", systemImage: "safari")
            }
        }
    }
}

#Preview {
    LinkListView()
}
