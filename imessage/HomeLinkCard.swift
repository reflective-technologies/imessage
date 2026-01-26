//
//  HomeLinkCard.swift
//  imessage
//
//  Created by hunter diamond on 1/23/26.
//

import SwiftUI
import AppKit

// MARK: - Dominant Color Extractor

extension NSImage {
    func dominantColor() -> Color {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Color(hex: "#2B2E30")
        }
        
        let width = 50  // Sample at lower resolution for performance
        let height = 50
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Color(hex: "#2B2E30")
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            return Color(hex: "#2B2E30")
        }
        
        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0
        
        // Sample from the bottom portion of the image for the gradient color
        let startY = height / 2
        for y in startY..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = CGFloat(pointer[offset])
                let g = CGFloat(pointer[offset + 1])
                let b = CGFloat(pointer[offset + 2])
                
                // Weight darker/more saturated colors more heavily
                let brightness = (r + g + b) / 3
                let weight = max(0.1, 1 - (brightness / 255) * 0.5)
                
                totalR += r * weight
                totalG += g * weight
                totalB += b * weight
                count += weight
            }
        }
        
        let avgR = totalR / count / 255
        let avgG = totalG / count / 255
        let avgB = totalB / count / 255
        
        // Darken the color slightly for better text contrast
        let darkenFactor: CGFloat = 0.7
        return Color(
            red: avgR * darkenFactor,
            green: avgG * darkenFactor,
            blue: avgB * darkenFactor
        )
    }
}

// MARK: - Home Link Card

struct HomeLinkCard: View {
    @ObservedObject var link: ExtractedLink
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var dominantColor: Color = Color(hex: "#2B2E30")

    private let cardWidth: CGFloat = 320
    private let cardHeight: CGFloat = 280

    private var isTwitterLink: Bool {
        let host = link.url.host ?? ""
        return host.contains("x.com") || host.contains("twitter.com")
    }

    var body: some View {
        Group {
            if isTwitterLink, let ogData = link.openGraphData {
                twitterCardView(ogData: ogData)
            } else {
                regularCardView
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            link.loadOpenGraphData()
        }
    }

    // MARK: - Twitter Card View
    @ViewBuilder
    private func twitterCardView(ogData: OpenGraphData) -> some View {
        let hasImage = ogData.imageURL != nil
        
        ZStack {
            // Background - media image or solid default color
            if let imageURLString = ogData.imageURL,
               let imageURL = URL(string: imageURLString) {
                CachedAsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    default:
                        Rectangle()
                            .fill(Color(hex: "#2B2E30"))
                    }
                } onImageLoaded: { nsImage in
                    dominantColor = nsImage.dominantColor()
                }
            } else {
                Rectangle()
                    .fill(Color(hex: "#2B2E30"))
            }

            // Gradient overlay only when there's an image
            if hasImage {
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.black.opacity(0.7), location: 0.3),
                            .init(color: Color.black.opacity(0.95), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: cardHeight * 0.7)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                // Tweet text
                if let description = ogData.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(hasImage ? 4 : 6)
                        .multilineTextAlignment(.leading)
                }

                // Author row with profile pic, handle, and x.com link
                HStack(spacing: 6) {
                    if let profileURL = ogData.twitterProfileImageURL,
                       let imageURL = URL(string: profileURL) {
                        CachedAsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 18, height: 18)
                                    .clipShape(Circle())
                            default:
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }

                    // Author name and handle
                    if let authorName = ogData.twitterAuthorName {
                        Text(authorName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    if let handle = ogData.twitterHandle {
                        Text(handle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("x.com")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            
            // "From {Name}" pill in top-left
            VStack {
                HStack {
                    SenderPill(name: link.displayContactName, profileImage: link.contactPhoto)
                    Spacer()
                }
                Spacer()
            }
            .padding(12)
        }
    }

    // MARK: - Regular Card View
    private var regularCardView: some View {
        ZStack {
            // Background image
            if let imageURLString = link.openGraphData?.imageURL,
               let imageURL = URL(string: imageURLString) {
                CachedAsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(hex: "#2B2E30"))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color(hex: "#2B2E30"))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                    @unknown default:
                        EmptyView()
                    }
                } onImageLoaded: { nsImage in
                    // Extract dominant color when image loads
                    dominantColor = nsImage.dominantColor()
                }
            } else {
                Rectangle()
                    .fill(Color(hex: "#2B2E30"))
            }

            // Gradient overlay
            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: dominantColor.opacity(0.6), location: 0.3),
                        .init(color: dominantColor.opacity(0.95), location: 0.7),
                        .init(color: dominantColor, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: cardHeight * 0.6)
            }

            // Content overlay
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                // Title
                Text(link.displayTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                // Domain row
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))

                    Text((link.url.host ?? "").lowercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            
            // "From {Name}" pill in top-left
            VStack {
                HStack {
                    SenderPill(name: link.displayContactName, profileImage: link.contactPhoto)
                    Spacer()
                }
                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Sender Pill (iMessage style "From Name" badge)
struct SenderPill: View {
    let name: String
    let profileImage: Data?
    
    private var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Avatar with initial
            ContactAvatarView(
                name: name,
                profileImage: profileImage,
                size: 24
            )
            
            // "From {FirstName}"
            Text("From ")
                .foregroundColor(.secondary) +
            Text(firstName)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .font(.system(size: 13))
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Cached Async Image with callback

struct CachedAsyncImage<Content: View>: View {
    let url: URL
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    let onImageLoaded: ((NSImage) -> Void)?
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content, onImageLoaded: ((NSImage) -> Void)? = nil) {
        self.url = url
        self.content = content
        self.onImageLoaded = onImageLoaded
    }
    
    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }
    
    private func loadImage() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let nsImage = NSImage(data: data) {
                let image = Image(nsImage: nsImage)
                phase = .success(image)
                onImageLoaded?(nsImage)
            } else {
                phase = .failure(URLError(.cannotDecodeContentData))
            }
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - Preview helpers

private extension Message {
    static let sample = Message(
        id: 1,
        text: "Check out this article",
        date: Date().addingTimeInterval(-3600),
        isFromMe: false,
        chatIdentifier: "iMessage;+15551234567",
        contactName: "John",
        payloadData: nil,
        senderIdentifier: "+15551234567",
        senderName: "John"
    )
}

private extension ExtractedLink {
    static func sampleWithImage() -> ExtractedLink {
        let link = ExtractedLink(
            url: URL(string: "https://www.wsj.com/politics/newsom-trump-showdown")!,
            message: .sample
        )
        link.openGraphData = OpenGraphData(
            title: "The Newsom-Trump Showdown Heats Up Davos",
            description: "California governor and former president clash at World Economic Forum.",
            imageURL: "https://images.wsj.net/im-12345/social",
            siteName: "WSJ",
            url: "https://www.wsj.com/politics/newsom-trump-showdown"
        )
        return link
    }
    
    static func sampleNoImage() -> ExtractedLink {
        let link = ExtractedLink(
            url: URL(string: "https://example.com/article")!,
            message: .sample
        )
        link.openGraphData = OpenGraphData(
            title: "Example Article Title That Might Be Long",
            description: "Some description here",
            imageURL: nil,
            siteName: "Example",
            url: "https://example.com/article"
        )
        return link
    }
}

#Preview("With Image") {
    HomeLinkCard(link: .sampleWithImage(), isSelected: false, onSelect: {})
        .padding()
        .background(Color(hex: "#1a1a1a"))
}

#Preview("No Image") {
    HomeLinkCard(link: .sampleNoImage(), isSelected: false, onSelect: {})
        .padding()
        .background(Color(hex: "#1a1a1a"))
}
