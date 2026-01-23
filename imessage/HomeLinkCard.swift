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
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onTapGesture {
            NSWorkspace.shared.open(link.url)
        }
        .onAppear {
            link.loadOpenGraphData()
        }
    }

    // MARK: - Twitter Card View
    @ViewBuilder
    private func twitterCardView(ogData: OpenGraphData) -> some View {
        ZStack(alignment: .bottom) {
            // Background - media image or dark gray
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
                            .fill(Color(hex: "#1C1C1E"))
                    }
                } onImageLoaded: { nsImage in
                    dominantColor = nsImage.dominantColor()
                }
            } else {
                Rectangle()
                    .fill(Color(hex: "#1C1C1E"))
            }

            // Gradient overlay for text readability
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

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                // Tweet text
                if let description = ogData.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                // Author row with profile pic
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
                }

                // Engagement stats row
                HStack(spacing: 12) {
                    if let likes = ogData.twitterLikes {
                        HStack(spacing: 3) {
                            Image(systemName: "heart")
                                .font(.system(size: 10))
                            Text("\(likes)")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }

                    if let replies = ogData.twitterReplies {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 10))
                            Text("\(replies)")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Text("x.com")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Sender row
                HStack(spacing: 6) {
                    ContactAvatarView(
                        name: link.displayContactName,
                        profileImage: link.contactPhoto,
                        size: 16
                    )

                    Text(link.displayContactName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    // MARK: - Regular Card View
    private var regularCardView: some View {
        ZStack(alignment: .bottom) {
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

                // Sender and domain row
                HStack(spacing: 8) {
                    // Sender avatar and name
                    ContactAvatarView(
                        name: link.displayContactName,
                        profileImage: link.contactPhoto,
                        size: 20
                    )

                    Text(link.displayContactName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))

                    // Domain
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))

                    Text((link.url.host ?? "").uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
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
        payloadData: nil
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
    HomeLinkCard(link: .sampleWithImage())
        .padding()
        .background(Color(hex: "#1a1a1a"))
}

#Preview("No Image") {
    HomeLinkCard(link: .sampleNoImage())
        .padding()
        .background(Color(hex: "#1a1a1a"))
}
