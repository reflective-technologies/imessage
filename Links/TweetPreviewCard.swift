//
//  TweetPreviewCard.swift
//  Links
//
//  Created on 1/23/26.
//

import SwiftUI

/// Tweet preview card matching iMessage's native style
struct TweetPreviewCard: View {
    let ogData: OpenGraphData
    let url: URL

    // Parse title for author info if not already parsed
    private var authorDisplay: String {
        if let name = ogData.twitterAuthorName, let handle = ogData.twitterHandle {
            return "\(name) (\(handle))"
        } else if let title = ogData.title {
            // Title might be "Author (@handle)\n11K likes..."
            if let firstLine = title.components(separatedBy: "\n").first {
                return firstLine
            }
            return title
        }
        return "X"
    }

    private var engagementDisplay: String? {
        if let likes = ogData.twitterLikes, let replies = ogData.twitterReplies {
            return "\(likes) likes · \(replies) replies"
        } else if let likes = ogData.twitterLikes {
            return "\(likes) likes"
        } else if let title = ogData.title {
            // Check if engagement is in title
            let lines = title.components(separatedBy: "\n")
            if lines.count > 1 {
                return lines[1]
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tweet text (description/summary) - main content at top
            if let description = ogData.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Author row - profile pic + name + handle
            HStack(spacing: 6) {
                // Profile picture
                if let profileURL = ogData.twitterProfileImageURL,
                   let imageURL = URL(string: profileURL) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    }
                }

                // Author name and handle
                Text(authorDisplay)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Engagement stats
            if let engagement = engagementDisplay {
                Text(engagement)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Domain
            Text("x.com")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

/// Large tweet card with media image - matching iMessage style
struct TweetPreviewCardLarge: View {
    let ogData: OpenGraphData
    let url: URL

    private var authorDisplay: String {
        if let name = ogData.twitterAuthorName, let handle = ogData.twitterHandle {
            return "\(name) (\(handle))"
        } else if let title = ogData.title {
            if let firstLine = title.components(separatedBy: "\n").first {
                return firstLine
            }
            return title
        }
        return "X"
    }

    private var engagementDisplay: String? {
        if let likes = ogData.twitterLikes, let replies = ogData.twitterReplies {
            return "\(likes) likes · \(replies) replies"
        } else if let likes = ogData.twitterLikes {
            return "\(likes) likes"
        } else if let title = ogData.title {
            let lines = title.components(separatedBy: "\n")
            if lines.count > 1 {
                return lines[1]
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media image at top
            if let imageURLString = ogData.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(ProgressView().scaleEffect(0.8))
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // Tweet text
                if let description = ogData.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Author row
                HStack(spacing: 6) {
                    if let profileURL = ogData.twitterProfileImageURL,
                       let imageURL = URL(string: profileURL) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 16, height: 16)
                                    .clipShape(Circle())
                            default:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }

                    Text(authorDisplay)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }

                // Engagement
                if let engagement = engagementDisplay {
                    Text(engagement)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Domain
                Text("x.com")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
