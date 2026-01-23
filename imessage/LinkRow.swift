//
//  LinkRow.swift
//  imessage
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side - Text content
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
                
                // Metadata row
                HStack(spacing: 6) {
                    // Sender avatar and name
                    ContactAvatarView(
                        name: link.displayContactName,
                        profileImage: nil,
                        size: 20
                    )
                    
                    Text(link.displayContactName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Domain
                    Text((link.url.host ?? "").uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Time
                    Text(link.message.date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
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
        .padding(16)
        .frame(maxWidth: 800, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.3) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
        payloadData: nil
    )

    static let sampleFromOther = Message(
        id: 2,
        text: "Did you read this? https://developer.apple.com",
        date: Date().addingTimeInterval(-7200),
        isFromMe: false,
        chatIdentifier: "iMessage;+15557654321",
        contactName: "Taylor Swift",
        payloadData: nil
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
