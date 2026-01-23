//
//  NewListRow.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation
import SwiftUI

// MARK: - Contact Avatar View (iMessage style)
struct ContactAvatarView: View {
    let name: String
    let profileImage: Data?
    let size: CGFloat
    
    init(name: String, profileImage: Data? = nil, size: CGFloat = 32) {
        self.name = name
        self.profileImage = profileImage
        self.size = size
    }
    
    private var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.first.map(String.init) ?? ""
        let lastInitial = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        return (firstInitial + lastInitial).uppercased()
    }
    
    // Generate a consistent color based on the name (like iMessage)
    private var backgroundColor: Color {
        let colors: [Color] = [
            Color(red: 0.35, green: 0.78, blue: 0.98), // Light blue
            Color(red: 0.38, green: 0.85, blue: 0.52), // Green
            Color(red: 1.0, green: 0.62, blue: 0.27),  // Orange
            Color(red: 0.99, green: 0.42, blue: 0.42), // Red
            Color(red: 0.69, green: 0.53, blue: 0.98), // Purple
            Color(red: 0.98, green: 0.75, blue: 0.35), // Yellow
            Color(red: 0.55, green: 0.63, blue: 0.98), // Indigo
        ]
        
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    var body: some View {
        Group {
            if let imageData = profileImage, let uiImage = NSImage(data: imageData) {
                Image(nsImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(backgroundColor.gradient)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

// MARK: - Link Row
struct NewLinkRow: View {
    let title: String
    let description: String?
    let domain: String
    let readTime: String?
    let imageURL: String?
    let senderName: String?
    let senderProfileImage: Data?
    
    @State private var isHovered = false
    
    init(
        title: String,
        description: String?,
        domain: String,
        readTime: String?,
        imageURL: String?,
        senderName: String? = nil,
        senderProfileImage: Data? = nil
    ) {
        self.title = title
        self.description = description
        self.domain = domain
        self.readTime = readTime
        self.imageURL = imageURL
        self.senderName = senderName
        self.senderProfileImage = senderProfileImage
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side - Text content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // Description
                if let description = description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
                
                
                
                // Metadata row
                HStack(spacing: 6) {
                    // Sender avatar and name
                    if let senderName = senderName {
                        ContactAvatarView(
                            name: senderName,
                            profileImage: senderProfileImage,
                            size: 20
                        )
                        
                        Text(senderName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Domain
                    Text(domain.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    // Read time
                    if let readTime = readTime {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(readTime)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Right side - Thumbnail image
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
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
            }
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(Color.white.opacity(isHovered ? 0.1 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(isHovered ? 0 : 0.1))
                .frame(height: 1)
        }
    }
}

// Convenience initializer for ExtractedLink
extension NewLinkRow {
    init(link: ExtractedLink, senderProfileImage: Data? = nil) {
        self.title = link.openGraphData?.title ?? link.url.host ?? link.url.absoluteString
        self.description = link.openGraphData?.description
        self.domain = link.url.host ?? ""
        self.readTime = nil
        self.imageURL = link.openGraphData?.imageURL
        self.senderName = link.displayContactName
        self.senderProfileImage = senderProfileImage
    }
}

#Preview {
    VStack(spacing: 0) {
        NewLinkRow(
            title: "Apple Announces iPhone 17 Pro and Pro Max With New Design, Larger Battery, and More",
            description: "Apple today introduced the iPhone 17 Pro and iPhone 17 Pro Max. Both devices feature a new al...",
            domain: "macrumors.com",
            readTime: "4 MIN",
            imageURL: nil,
            senderName: "John Appleseed"
        )
        
        NewLinkRow(
            title: "JWST give a new look at the Pillars of Creation's majestic explosion of young stars",
            description: "First imaged in 1995, this iconic kaleidoscope of color is part of the Eagle Nebula.",
            domain: "popsci.com",
            readTime: "2 MIN",
            imageURL: nil,
            senderName: "Sarah Miller"
        )
        
        NewLinkRow(
            title: "Single name test",
            description: "Testing how single names look with initials.",
            domain: "example.com",
            readTime: "1 MIN",
            imageURL: nil,
            senderName: "Alex"
        )
    }
    .padding()
    .background(Color(hex: "#23282A"))
}
