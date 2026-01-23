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

// MARK: - Message List View
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
                        
                        // Message bubble - show tail only on sent messages (blue) and only on last in sequence
                        let isLast = isLastInSequence(for: index)
                        MessageBubbleView(
                            message: message,
                            showTail: message.isFromMe && isLast
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
        .background(Color.black)
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
                    .font(.system(size: 17))
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
        let radius: CGFloat = 17
        
        if !showTail {
            return RoundedRectangle(cornerRadius: radius).path(in: rect)
        }
        
        // Use a combined approach: rounded rect + tail overlay
        var path = Path()
        
        // Draw rounded rectangle for the main bubble
        let bubbleRect = RoundedRectangle(cornerRadius: radius).path(in: rect)
        path.addPath(bubbleRect)
        
        // Add tail as a separate curved shape
        if isFromMe {
            // Tail on bottom-right - pushed further into bubble for seamless blend
            var tailPath = Path()
            
            // Start deep inside the bubble
            tailPath.move(to: CGPoint(x: rect.maxX - 15, y: rect.maxY - 5))
            
            // Curve along the bottom-right, staying inside bubble
            tailPath.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - 3),
                control: CGPoint(x: rect.maxX - 8, y: rect.maxY)
            )
            
            // Curve out to tail tip (rounded)
            tailPath.addCurve(
                to: CGPoint(x: rect.maxX + 5, y: rect.maxY + 2),
                control1: CGPoint(x: rect.maxX + 3, y: rect.maxY - 1),
                control2: CGPoint(x: rect.maxX + 6, y: rect.maxY)
            )
            
            // Round the tip and curve back
            tailPath.addCurve(
                to: CGPoint(x: rect.maxX - 8, y: rect.maxY + 1),
                control1: CGPoint(x: rect.maxX + 4, y: rect.maxY + 4),
                control2: CGPoint(x: rect.maxX - 2, y: rect.maxY + 3)
            )
            
            // Curve back into the bubble
            tailPath.addQuadCurve(
                to: CGPoint(x: rect.maxX - 15, y: rect.maxY - 5),
                control: CGPoint(x: rect.maxX - 14, y: rect.maxY)
            )
            
            tailPath.closeSubpath()
            path.addPath(tailPath)
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
