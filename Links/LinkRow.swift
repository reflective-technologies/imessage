//
//  LinkRow.swift
//  Links
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
import SwiftUI

struct LinkRow: View {
    @ObservedObject var link: ExtractedLink
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    init(link: ExtractedLink, isSelected: Bool = false, onSelect: @escaping () -> Void = {}) {
        self.link = link
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
    
    private var isTwitterLink: Bool {
        let host = link.url.host ?? ""
        return host.contains("x.com") || host.contains("twitter.com")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sender info row (always shown at top)
            HStack(spacing: 6) {
                ContactAvatarView(
                    name: link.displayContactName,
                    profileImage: link.contactPhoto,
                    size: 20
                )

                Text(link.displayContactName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text("·")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(link.message.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
            }

            // Content area - different layout for Twitter vs regular links
            if isTwitterLink, let ogData = link.openGraphData {
                // Twitter-specific card - show if we have any data
                if ogData.imageURL != nil {
                    TweetPreviewCardLarge(ogData: ogData, url: link.url)
                        .frame(maxWidth: 500)
                } else {
                    TweetPreviewCard(ogData: ogData, url: link.url)
                        .frame(maxWidth: 500)
                }
            } else if isTwitterLink && link.openGraphData == nil {
                // Twitter link but no OG data yet - show placeholder
                VStack(alignment: .leading, spacing: 8) {
                    if link.isLoadingOpenGraph {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading tweet...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("x.com")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: 500, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            } else {
                // Regular link layout
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        Text(link.displayTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Description
                        if let description = link.openGraphData?.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(3)
                        }

                        // Domain
                        Text((link.url.host ?? "").uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Right side - OG image
                    if let imageURLString = link.openGraphData?.imageURL,
                       let imageURL = URL(string: imageURLString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else if link.isLoadingOpenGraph {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 900, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? Color.blue.opacity(0.3) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(isHovered || isSelected ? 0 : 0.1))
                .frame(height: 1)
        }
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
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.displayTitle), from \(link.displayContactName)")
    }
}

// MARK: - Local preview helpers (scoped to this file)

private extension Message {
    static let sampleFromMe = Message(
        id: 1,
        text: "Check this out: https://www.apple.com",
        date: Date().addingTimeInterval(-3600),
        isFromMe: true,
        chatIdentifier: "iMessage;+15551234567",
        contactName: "Me",
        payloadData: nil,
        senderIdentifier: nil,
        senderName: nil
    )

    static let sampleFromOther = Message(
        id: 2,
        text: "Did you read this? https://developer.apple.com",
        date: Date().addingTimeInterval(-7200),
        isFromMe: false,
        chatIdentifier: "iMessage;+15557654321",
        contactName: "Taylor Swift",
        payloadData: nil,
        senderIdentifier: "+15557654321",
        senderName: "Taylor Swift"
    )
}

private extension ExtractedLink {
    static func sampleBasic() -> ExtractedLink {
        ExtractedLink(
            url: URL(string: "https://www.apple.com")!,
            message: .sampleFromOther
        )
    }

    static func sampleWithOpenGraph() -> ExtractedLink {
        let link = ExtractedLink(
            url: URL(string: "https://developer.apple.com/wwdc")!,
            message: .sampleFromMe
        )
        link.openGraphData = OpenGraphData(
            title: "WWDC - Apple Developer Conference",
            description: "Join developers worldwide for an exciting week of technology and community. Learn about the latest Apple technologies.",
            imageURL: "https://devimages.apple.com.edgekey.net/assets/elements/icons/wwdc/wwdc-128x128_2x.png",
            siteName: "Apple Developer",
            url: "https://developer.apple.com/wwdc"
        )
        return link
    }

    static func sampleLoading() -> ExtractedLink {
        let link = ExtractedLink(
            url: URL(string: "https://example.com/article")!,
            message: .sampleFromOther
        )
        link.isLoadingOpenGraph = true
        return link
    }
}

// MARK: - Previews

#Preview("Basic") {
    VStack(spacing: 0) {
        LinkRow(link: .sampleBasic(), isSelected: false, onSelect: {})
        LinkRow(link: .sampleWithOpenGraph(), isSelected: true, onSelect: {})
        LinkRow(link: .sampleLoading(), isSelected: false, onSelect: {})
    }
    .padding()
    .background(Color(hex: "#23282A"))
}
