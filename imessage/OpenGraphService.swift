//
//  OpenGraphService.swift
//  imessage
//
//  Created by hunter diamond on 1/22/26.
//

import Foundation

class OpenGraphService {
    static let shared = OpenGraphService()

    private var cache: [String: OpenGraphData] = [:]
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        // Set User-Agent to look like a real browser
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        session = URLSession(configuration: config)
    }

    func fetchMetadata(for url: URL) async -> OpenGraphData? {
        let urlString = url.absoluteString

        // Check cache first
        if let cached = cache[urlString] {
            return cached
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Not an HTTP response for \(urlString)")
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP \(httpResponse.statusCode) for \(urlString)")
                return nil
            }

            guard let html = String(data: data, encoding: .utf8) else {
                print("❌ Failed to decode HTML for \(urlString)")
                return nil
            }

            // Debug: Check if we got actual HTML or JavaScript redirect
            let htmlPreview = String(html.prefix(500))
            if html.contains("twitter:") || html.contains("og:") {
                print("📄 HTML contains meta tags for \(urlString)")
            } else {
                print("⚠️  HTML may not contain meta tags for \(urlString)")
                print("📄 First 500 chars: \(htmlPreview)")
            }

            let ogData = parseOpenGraph(from: html, url: urlString)

            if ogData.hasData {
                print("✅ Found OpenGraph data for \(urlString)")
                print("   Title: \(ogData.title ?? "none")")
                print("   Image: \(ogData.imageURL ?? "none")")
                print("   Site: \(ogData.siteName ?? "none")")
            } else {
                print("⚠️  No OpenGraph data found for \(urlString)")
            }

            cache[urlString] = ogData
            return ogData

        } catch {
            print("❌ Failed to fetch OpenGraph data for \(urlString): \(error)")
            return nil
        }
    }

    private func parseOpenGraph(from html: String, url: String) -> OpenGraphData {
        var title: String?
        var description: String?
        var imageURL: String?
        var siteName: String?

        // Also track Twitter-specific tags
        var twitterTitle: String?
        var twitterDescription: String?
        var twitterImage: String?
        var twitterSite: String?

        // Parse meta tags - need to handle multiple formats:
        // <meta property="og:title" content="...">
        // <meta name="twitter:title" content="...">
        // <meta content="..." property="og:title">
        // <meta content="..." name="twitter:title">
        // Also handle attributes in any order with optional spaces

        // More flexible pattern that captures property/name and content in any order
        let metaTagPattern = #"<meta\s+([^>]+)>"#

        guard let metaRegex = try? NSRegularExpression(pattern: metaTagPattern, options: [.caseInsensitive]) else {
            return OpenGraphData(title: title, description: description, imageURL: imageURL, siteName: siteName, url: url)
        }

        let nsString = html as NSString
        let metaMatches = metaRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in metaMatches {
            guard match.numberOfRanges >= 2 else { continue }

            let attributesString = nsString.substring(with: match.range(at: 1))

            // Extract property/name and content from attributes
            var propertyName: String?
            var contentValue: String?

            // Match property="..." or name="..."
            if let propMatch = try? NSRegularExpression(pattern: #"(?:property|name)=["\']([^"\']+)["\']"#, options: [.caseInsensitive])
                .firstMatch(in: attributesString, options: [], range: NSRange(location: 0, length: attributesString.count)) {
                propertyName = (attributesString as NSString).substring(with: propMatch.range(at: 1))
            }

            // Match content="..."
            if let contentMatch = try? NSRegularExpression(pattern: #"content=["\']([^"\']*)["\']"#, options: [.caseInsensitive])
                .firstMatch(in: attributesString, options: [], range: NSRange(location: 0, length: attributesString.count)) {
                contentValue = (attributesString as NSString).substring(with: contentMatch.range(at: 1))
            }

            guard let property = propertyName?.lowercased(),
                  let content = contentValue,
                  !content.isEmpty else {
                continue
            }

            switch property {
            // OpenGraph tags (preferred)
            case "og:title":
                if title == nil {
                    title = decodeHTMLEntities(content)
                }
            case "og:description":
                if description == nil {
                    description = decodeHTMLEntities(content)
                }
            case "og:image", "og:image:url", "og:image:secure_url":
                if imageURL == nil {
                    imageURL = content
                }
            case "og:site_name":
                if siteName == nil {
                    siteName = decodeHTMLEntities(content)
                }

            // Twitter tags
            case "twitter:title":
                if twitterTitle == nil {
                    twitterTitle = decodeHTMLEntities(content)
                }
            case "twitter:description":
                if twitterDescription == nil {
                    twitterDescription = decodeHTMLEntities(content)
                }
            case "twitter:image", "twitter:image:src":
                if twitterImage == nil {
                    twitterImage = content
                }
            case "twitter:site", "twitter:creator":
                if twitterSite == nil {
                    twitterSite = decodeHTMLEntities(content)
                }

            // Generic description fallback
            case "description":
                if description == nil && twitterDescription == nil {
                    description = decodeHTMLEntities(content)
                }

            default:
                break
            }
        }

        // Fallback chain: og > twitter > generic
        if title == nil {
            title = twitterTitle
        }
        if description == nil {
            description = twitterDescription
        }
        if imageURL == nil {
            imageURL = twitterImage
        }
        if siteName == nil {
            siteName = twitterSite
        }

        // Final fallback to <title> tag if still no title
        if title == nil {
            let titlePattern = #"<title[^>]*>(.*?)</title>"#
            if let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = html as NSString
                if let match = titleRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
                   match.numberOfRanges >= 2 {
                    title = decodeHTMLEntities(nsString.substring(with: match.range(at: 1)))
                }
            }
        }

        return OpenGraphData(
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName,
            url: url
        )
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
