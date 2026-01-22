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
    @State private var isHovering = false

    private var shouldShowMessageText: Bool {
        guard let messageText = link.message.text else { return false }

        // Trim whitespace and newlines
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = link.url.absoluteString

        // Check if the message is just the URL
        if trimmedMessage == urlString {
            return false
        }

        // Check if the message is the URL without protocol
        if let urlWithoutProtocol = urlString.components(separatedBy: "://").last,
           trimmedMessage == urlWithoutProtocol {
            return false
        }

        // Check if the message is the URL with trailing slash differences
        if trimmedMessage.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
            return false
        }

        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // OpenGraph preview card
            if let ogData = link.openGraphData, ogData.hasData {
                OpenGraphPreviewCard(ogData: ogData, url: link.url)
            } else if link.isLoadingOpenGraph {
                LinkPreviewPlaceholder()
            } else {
                SimpleLinkView(link: link)
            }

            // Separator between preview and context
            Divider()
                .opacity(0.08)

            // Message context and metadata
            let vStackSpacing: CGFloat = shouldShowMessageText ? 12 : 0
            let topPadding: CGFloat = shouldShowMessageText ? 2 : 0
            let containerPadding: EdgeInsets = shouldShowMessageText
                ? EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
                : EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)

            VStack(alignment: .leading, spacing: vStackSpacing) {
                // Message context - only show if it's more than just the URL
                if shouldShowMessageText, let messageText = link.message.text {
                    Text(messageText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                // Metadata footer
                HStack(spacing: 10) {
                    Image(systemName: link.message.isFromMe ? "person.fill" : "person.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    Text(link.displayContactName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))

                    Text(link.message.date, style: .relative)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                        .opacity(0.8)
                }
                .padding(.top, topPadding)
            }
            .padding(containerPadding)
            .background(
                Color(.textBackgroundColor)
                    .opacity(0.9)
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separatorColor).opacity(isHovering ? 0.35 : 0.25), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(isHovering ? 0.12 : 0.08), radius: isHovering ? 10 : 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
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
            NSWorkspace.shared.open(link.url)
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
        contactName: "Me"
    )

    static let sampleFromOther = Message(
        id: 2,
        text: "Did you read this? https://developer.apple.com",
        date: Date().addingTimeInterval(-7200),
        isFromMe: false,
        chatIdentifier: "iMessage;+15557654321",
        contactName: "Taylor"
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
            title: "WWDC",
            description: "Join developers worldwide for an exciting week of technology and community.",
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
    LinkRow(link: .sampleBasic())
        .padding()
        .frame(maxWidth: 520)
        .background(Color(.windowBackgroundColor))
}

#Preview("With OpenGraph") {
    LinkRow(link: .sampleWithOpenGraph())
        .padding()
        .frame(maxWidth: 520)
        .background(Color(.windowBackgroundColor))
}

#Preview("Loading") {
    LinkRow(link: .sampleLoading())
        .padding()
        .frame(maxWidth: 520)
        .background(Color(.windowBackgroundColor))
}
