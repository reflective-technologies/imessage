//
//  MessageView.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import SwiftUI

// MARK: - Message Bubble Colors
extension Color {
    static let iMessageBlue = Color(hex: "0B93F6")
    static let iMessageGray = Color(hex: "3B3B3D")
}

// MARK: - Sample Data for Preview
struct SampleMessage: Identifiable {
    let id = UUID()
    let text: String?
    let emoji: String?
    let date: Date
    let isFromMe: Bool
    let deliveryStatus: DeliveryStatus?
    
    enum DeliveryStatus {
        case sent
        case delivered
        case read
    }
    
    init(text: String? = nil, emoji: String? = nil, date: Date, isFromMe: Bool, deliveryStatus: DeliveryStatus? = nil) {
        self.text = text
        self.emoji = emoji
        self.date = date
        self.isFromMe = isFromMe
        self.deliveryStatus = deliveryStatus
    }
}

// MARK: - Message Context View (shows surrounding messages for a link)
struct MessageContextView: View {
    let link: ExtractedLink
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Contact photo and name
                HStack(spacing: 10) {
                    ContactAvatarView(
                        name: link.displayContactName,
                        profileImage: link.contactPhoto,
                        size: 32
                    )
                    
                    Text(link.displayContactName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Open link button
                Button(action: {
                    NSWorkspace.shared.open(link.url)
                }) {
                    HStack(spacing: 4) {
                        Text("Open Link")
                            .font(.caption)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1C1C1E"))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Messages
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                RealMessageListView(messages: messages, highlightedMessageId: link.message.id)
            }
        }
        .onAppear {
            loadSurroundingMessages()
        }
        .onChange(of: link.id) { _, _ in
            loadSurroundingMessages()
        }
    }
    
    private func loadSurroundingMessages() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let surroundingMessages = try MessageService.shared.fetchSurroundingMessages(for: link.message)
                DispatchQueue.main.async {
                    self.messages = surroundingMessages
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load messages"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Real Message List View (uses actual Message model)
struct RealMessageListView: View {
    let messages: [Message]
    let highlightedMessageId: Int?
    
    /// Check if this is a group chat based on the first message
    private var isGroupChat: Bool {
        messages.first?.isGroupChat ?? false
    }
    
    init(messages: [Message], highlightedMessageId: Int? = nil) {
        self.messages = messages
        self.highlightedMessageId = highlightedMessageId
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 4) {
                            // Show timestamp if needed
                            if shouldShowTimestamp(for: index) {
                                TimestampView(date: message.date)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                            }
                            
                            // Show sender name for group chats when sender changes
                            if isGroupChat && !message.isFromMe && shouldShowSenderName(for: index) {
                                HStack {
                                    Text(message.senderDisplayName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 44) // Align with message bubble (avatar width + spacing)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                            
                            // Message bubble
                            let isLast = isLastInSequence(for: index)
                            let isHighlighted = message.id == highlightedMessageId
                            let showAvatar = isGroupChat && !message.isFromMe && isLast
                            
                            RealMessageBubbleView(
                                message: message,
                                showTail: isLast,
                                isHighlighted: isHighlighted,
                                showAvatar: showAvatar
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onAppear {
                // Scroll to highlighted message
                if let highlightedId = highlightedMessageId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(highlightedId, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private func shouldShowTimestamp(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        let timeDifference = currentMessage.date.timeIntervalSince(previousMessage.date)
        return timeDifference > 3600
    }
    
    /// For group chats: show sender name when sender changes from previous message
    private func shouldShowSenderName(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        // If previous was from me, show sender name
        if previousMessage.isFromMe {
            return true
        }
        
        // If sender changed, show name
        if currentMessage.senderIdentifier != previousMessage.senderIdentifier {
            return true
        }
        
        // If timestamp shown, also show sender name
        if shouldShowTimestamp(for: index) {
            return true
        }
        
        return false
    }
    
    private func isLastInSequence(for index: Int) -> Bool {
        let currentMessage = messages[index]
        
        guard index < messages.count - 1 else { return true }
        
        let nextMessage = messages[index + 1]
        
        // Different sender direction
        if nextMessage.isFromMe != currentMessage.isFromMe {
            return true
        }
        
        // For group chats: different sender within received messages
        if isGroupChat && !currentMessage.isFromMe {
            if nextMessage.senderIdentifier != currentMessage.senderIdentifier {
                return true
            }
        }
        
        // Large time gap
        let timeDifference = nextMessage.date.timeIntervalSince(currentMessage.date)
        if timeDifference > 3600 {
            return true
        }
        
        return false
    }
}

// MARK: - Real Message Bubble View (uses actual Message model)
struct RealMessageBubbleView: View {
    let message: Message
    let showTail: Bool
    let isHighlighted: Bool
    let showAvatar: Bool
    @State private var detectedURL: URL?
    @State private var openGraphData: OpenGraphData?
    @State private var isLoadingOG = false
    
    init(message: Message, showTail: Bool, isHighlighted: Bool = false, showAvatar: Bool = false) {
        self.message = message
        self.showTail = showTail
        self.isHighlighted = isHighlighted
        self.showAvatar = showAvatar
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromMe {
                Spacer(minLength: 60)
            } else {
                // Avatar for group chats (or placeholder to maintain alignment)
                if showAvatar {
                    ContactAvatarView(
                        name: message.senderDisplayName,
                        profileImage: message.senderPhoto,
                        size: 28
                    )
                } else {
                    // Invisible spacer to maintain alignment
                    Color.clear
                        .frame(width: 28, height: 28)
                }
            }
            
            if let text = message.text {
                // Check if it's a single emoji (large display)
                if isSingleEmoji(text) {
                    Text(text)
                        .font(.system(size: 80))
                } else {
                    VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                        // Show link preview if we have a URL
                        if let url = detectedURL {
                            LinkPreviewBubble(
                                url: url,
                                openGraphData: openGraphData,
                                isFromMe: message.isFromMe,
                                isLoading: isLoadingOG
                            )
                            .onTapGesture {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        // Show text bubble (with URL removed if we're showing preview)
                        let displayText = detectedURL != nil ? textWithoutURL(text) : text
                        if !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(displayText)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    MessageBubbleShape(isFromMe: message.isFromMe, showTail: showTail && detectedURL == nil)
                                        .fill(message.isFromMe ? Color.iMessageBlue : Color.iMessageGray)
                                )
                                .padding(.bottom, showTail && detectedURL == nil ? 3 : 0)
                        }
                    }
                    .overlay(
                        // Highlight ring for the message containing the link
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(Color.yellow, lineWidth: isHighlighted ? 1 : 0)
                            .padding(-1)
                    )
                }
            }
            
            if message.isFromMe {
                // No avatar spacer needed for sent messages
            } else {
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            detectAndLoadURL()
        }
    }
    
    private func isSingleEmoji(_ text: String) -> Bool {
        guard text.count == 1 else { return false }
        return text.unicodeScalars.first?.properties.isEmoji ?? false
    }
    
    private func detectAndLoadURL() {
        guard let text = message.text else { return }
        
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsString = text as NSString
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let firstMatch = matches?.first, let url = firstMatch.url {
            self.detectedURL = url
            loadOpenGraphData(for: url)
        }
    }
    
    private func loadOpenGraphData(for url: URL) {
        isLoadingOG = true
        
        // First try to extract from Apple's cached payload data (contains Twitter-specific info)
        if let cachedData = MessageService.shared.extractOpenGraphFromPayload(message.payloadData, for: url) {
            self.openGraphData = cachedData
            self.isLoadingOG = false
            return
        }
        
        // Fall back to fetching fresh OpenGraph data
        Task {
            let data = await OpenGraphService.shared.fetchMetadata(for: url)
            await MainActor.run {
                self.openGraphData = data
                self.isLoadingOG = false
            }
        }
    }
    
    private func textWithoutURL(_ text: String) -> String {
        guard let url = detectedURL else { return text }
        
        // Remove the URL from the text
        var result = text.replacingOccurrences(of: url.absoluteString, with: "")
        
        // Also try removing with trailing slash variations
        result = result.replacingOccurrences(of: url.absoluteString + "/", with: "")
        if url.absoluteString.hasSuffix("/") {
            result = result.replacingOccurrences(of: String(url.absoluteString.dropLast()), with: "")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Link Preview Bubble (iMessage style)
struct LinkPreviewBubble: View {
    let url: URL
    let openGraphData: OpenGraphData?
    let isFromMe: Bool
    let isLoading: Bool
    
    private var isTwitterLink: Bool {
        let host = url.host ?? ""
        return host.contains("x.com") || host.contains("twitter.com")
    }
    
    var body: some View {
        if isTwitterLink, let ogData = openGraphData, ogData.isTwitter {
            TwitterLinkPreviewBubble(url: url, openGraphData: ogData, isFromMe: isFromMe)
        } else {
            regularLinkPreview
        }
    }
    
    private var regularLinkPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image preview
            if let imageURLString = openGraphData?.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 140)
                            .overlay(ProgressView().scaleEffect(0.7))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 80)
                            .overlay(
                                Image(systemName: "link")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 100)
                    .overlay(ProgressView().scaleEffect(0.7))
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                if let title = openGraphData?.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                } else if !isLoading {
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                // Domain
                Text((url.host ?? "").lowercased())
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isFromMe ? Color(hex: "#003450") : Color.iMessageGray)
        }
        .frame(width: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Twitter Link Preview Bubble (iMessage style with cached tweet data)
struct TwitterLinkPreviewBubble: View {
    let url: URL
    let openGraphData: OpenGraphData
    let isFromMe: Bool
    
    private var authorDisplay: String {
        if let name = openGraphData.twitterAuthorName, let handle = openGraphData.twitterHandle {
            return "\(name) \(handle)"
        } else if let title = openGraphData.title {
            // Title might be "Author (@handle)\n11K likes..."
            if let firstLine = title.components(separatedBy: "\n").first {
                return firstLine
            }
            return title
        }
        return "X"
    }
    
    private var engagementDisplay: String? {
        if let likes = openGraphData.twitterLikes, let replies = openGraphData.twitterReplies {
            return "\(likes) likes · \(replies) replies"
        } else if let likes = openGraphData.twitterLikes {
            return "\(likes) likes"
        } else if let title = openGraphData.title {
            let lines = title.components(separatedBy: "\n")
            if lines.count > 1 {
                return lines[1]
            }
        }
        return nil
    }
    
    private var hasMediaImage: Bool {
        if let imageURL = openGraphData.imageURL {
            // Check that it's not just a profile image
            return !imageURL.contains("profile_images")
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media image at top (if available and not just profile pic)
            if hasMediaImage,
               let imageURLString = openGraphData.imageURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 140)
                            .overlay(ProgressView().scaleEffect(0.7))
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Tweet content
            VStack(alignment: .leading, spacing: 8) {
                // Tweet text (description)
                if let description = openGraphData.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Author row with profile pic
                HStack(spacing: 6) {
                    // Profile picture
                    if let profileURL = openGraphData.twitterProfileImageURL,
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                // Engagement stats
                if let engagement = engagementDisplay {
                    Text(engagement)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Domain
                Text("x.com")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isFromMe ? Color(hex: "#003450") : Color.iMessageGray)
        }
        .frame(width: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Message List View (for SampleMessage - kept for previews)
struct MessageListView: View {
    let messages: [SampleMessage]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    VStack(spacing: 4) {
                        // Show timestamp if needed
                        if shouldShowTimestamp(for: index) {
                            TimestampView(date: message.date)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        }
                        
                        // Message bubble - show tail on last message in sequence (both sent and received)
                        let isLast = isLastInSequence(for: index)
                        MessageBubbleView(
                            message: message,
                            showTail: isLast
                        )
                        
                        // Show delivery status only for the last sent message in a consecutive sequence
                        if message.isFromMe && message.deliveryStatus != nil && isLast {
                            DeliveryStatusView(status: message.deliveryStatus!)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        
    }
    
    private func shouldShowTimestamp(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentMessage = messages[index]
        let previousMessage = messages[index - 1]
        
        // Show timestamp if more than 1 hour apart
        let timeDifference = currentMessage.date.timeIntervalSince(previousMessage.date)
        return timeDifference > 3600
    }
    
    /// Determines if the message at this index is the last in a consecutive sequence from the same sender
    private func isLastInSequence(for index: Int) -> Bool {
        let currentMessage = messages[index]
        
        // If this is the last message, it's the last in its sequence
        guard index < messages.count - 1 else { return true }
        
        let nextMessage = messages[index + 1]
        
        // If the next message is from a different sender, this is the last in the sequence
        // Also check if there's a timestamp break (which visually separates sequences)
        if nextMessage.isFromMe != currentMessage.isFromMe {
            return true
        }
        
        // Check if there's a timestamp break before the next message
        let timeDifference = nextMessage.date.timeIntervalSince(currentMessage.date)
        if timeDifference > 3600 {
            return true
        }
        
        return false
    }
}

// MARK: - Timestamp View
struct TimestampView: View {
    let date: Date
    
    var body: some View {
        Text(formattedDate)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.gray)
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "'Today' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "'Yesterday' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE h:mm a"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy h:mm a"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: SampleMessage
    let showTail: Bool
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer(minLength: 60)
            }
            
            if let emoji = message.emoji {
                Text(emoji)
                    .font(.system(size: 80))
            } else if let text = message.text {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        MessageBubbleShape(isFromMe: message.isFromMe, showTail: showTail)
                            .fill(message.isFromMe ? Color.iMessageBlue : Color.iMessageGray)
                    )
                    .padding(.bottom, showTail ? 3 : 0) // Extra space for tail
            }
            
            if !message.isFromMe {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Message Bubble Shape
struct MessageBubbleShape: Shape {
    let isFromMe: Bool
    let showTail: Bool
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        
        // If no tail, just return a rounded rectangle
        if !showTail {
            return RoundedRectangle(cornerRadius: 15).path(in: rect)
        }
        
        var path = Path()
        
        if !isFromMe {
            // Received message - tail on bottom-left
            path.move(to: CGPoint(x: 20, y: height))
            path.addLine(to: CGPoint(x: width - 15, y: height))
            path.addCurve(
                to: CGPoint(x: width, y: height - 15),
                control1: CGPoint(x: width - 8, y: height),
                control2: CGPoint(x: width, y: height - 8)
            )
            path.addLine(to: CGPoint(x: width, y: 15))
            path.addCurve(
                to: CGPoint(x: width - 15, y: 0),
                control1: CGPoint(x: width, y: 8),
                control2: CGPoint(x: width - 8, y: 0)
            )
            path.addLine(to: CGPoint(x: 20, y: 0))
            path.addCurve(
                to: CGPoint(x: 5, y: 15),
                control1: CGPoint(x: 12, y: 0),
                control2: CGPoint(x: 5, y: 8)
            )
            path.addLine(to: CGPoint(x: 5, y: height - 10))
            path.addCurve(
                to: CGPoint(x: 0, y: height),
                control1: CGPoint(x: 5, y: height - 1),
                control2: CGPoint(x: 0, y: height)
            )
            path.addLine(to: CGPoint(x: -1, y: height))
            path.addCurve(
                to: CGPoint(x: 12, y: height - 4),
                control1: CGPoint(x: 4, y: height + 1),
                control2: CGPoint(x: 8, y: height - 1)
            )
            path.addCurve(
                to: CGPoint(x: 20, y: height),
                control1: CGPoint(x: 15, y: height),
                control2: CGPoint(x: 20, y: height)
            )
        } else {
            // Sent message - tail on bottom-right
            path.move(to: CGPoint(x: width - 20, y: height))
            path.addLine(to: CGPoint(x: 15, y: height))
            path.addCurve(
                to: CGPoint(x: 0, y: height - 15),
                control1: CGPoint(x: 8, y: height),
                control2: CGPoint(x: 0, y: height - 8)
            )
            path.addLine(to: CGPoint(x: 0, y: 15))
            path.addCurve(
                to: CGPoint(x: 15, y: 0),
                control1: CGPoint(x: 0, y: 8),
                control2: CGPoint(x: 8, y: 0)
            )
            path.addLine(to: CGPoint(x: width - 20, y: 0))
            path.addCurve(
                to: CGPoint(x: width - 5, y: 15),
                control1: CGPoint(x: width - 12, y: 0),
                control2: CGPoint(x: width - 5, y: 8)
            )
            path.addLine(to: CGPoint(x: width - 5, y: height - 12))
            path.addCurve(
                to: CGPoint(x: width, y: height),
                control1: CGPoint(x: width - 5, y: height - 1),
                control2: CGPoint(x: width, y: height)
            )
            path.addLine(to: CGPoint(x: width + 1, y: height))
            path.addCurve(
                to: CGPoint(x: width - 12, y: height - 4),
                control1: CGPoint(x: width - 4, y: height + 1),
                control2: CGPoint(x: width - 8, y: height - 1)
            )
            path.addCurve(
                to: CGPoint(x: width - 20, y: height),
                control1: CGPoint(x: width - 15, y: height),
                control2: CGPoint(x: width - 20, y: height)
            )
        }
        
        return path
    }
}

// MARK: - Delivery Status View
struct DeliveryStatusView: View {
    let status: SampleMessage.DeliveryStatus
    
    var body: some View {
        HStack {
            Spacer()
            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .padding(.trailing, 4)
        }
    }
    
    private var statusText: String {
        switch status {
        case .sent:
            return "Sent"
        case .delivered:
            return "Delivered"
        case .read:
            return "Read"
        }
    }
}

// MARK: - Preview
#Preview {
    let calendar = Calendar.current
    let now = Date()
    
    // Create dates for the conversation
    let sundayEvening = calendar.date(byAdding: .day, value: -5, to: now)!
    let sundayLater = calendar.date(byAdding: .hour, value: 4, to: sundayEvening)!
    let today = now
    
    let sampleMessages: [SampleMessage] = [
        // Sunday 5:44 PM
        SampleMessage(emoji: "💪", date: sundayEvening, isFromMe: false),
        SampleMessage(text: "Insane catch", date: sundayEvening, isFromMe: true),
        SampleMessage(text: "So good", date: sundayEvening, isFromMe: false),
        SampleMessage(text: "Moving on to Denver", date: sundayEvening, isFromMe: false),
        
        // Sunday 9:26 PM
        SampleMessage(text: "Good win", date: sundayLater, isFromMe: true, deliveryStatus: .sent),
        SampleMessage(text: "Good Grief", date: sundayLater, isFromMe: true, deliveryStatus: .delivered),
        SampleMessage(text: "Yup. Texans defense was tough and luckily we're on to the AFC championship", date: sundayLater, isFromMe: false),
        
        // Today 8:18 PM
        SampleMessage(text: "Btw, if you have Amazon prime check out the series \"Steal\". It's very good", date: today, isFromMe: false),
    ]
    
    return MessageListView(messages: sampleMessages)
}
