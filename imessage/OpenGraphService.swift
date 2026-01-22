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
        // Set User-Agent to look like a social media crawler (better for OpenGraph)
        config.httpAdditionalHeaders = [
            "User-Agent": "facebookexternalua Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Cache-Control": "no-cache"
        ]
        session = URLSession(configuration: config)
    }

    func fetchMetadata(for url: URL) async -> OpenGraphData? {
        let urlString = url.absoluteString

        // Check persistent cache first (like iMessage does)
        if let cached = OpenGraphCacheService.shared.getCachedData(for: url) {
            print("📦 Using cached OpenGraph data for \(urlString)")
            return cached
        }

        // Check memory cache
        if let cached = cache[urlString] {
            return cached
        }

        // For X.com/Twitter, use special handling with Twitterbot User-Agent
        let host = url.host ?? ""
        let isTwitter = host == "x.com" || host == "twitter.com" || host == "www.x.com" || host == "www.twitter.com"

        if isTwitter {
            print("🔍 Detected Twitter/X URL: \(url)")
            if let twitterData = await fetchTwitterMetadata(for: url) {
                print("✅ Got Twitter metadata with Twitterbot UA")
                cache[urlString] = twitterData
                // Save to persistent cache
                OpenGraphCacheService.shared.cacheData(twitterData, for: url)
                print("💾 Saved Twitter data to persistent cache")
                return twitterData
            } else {
                print("⚠️  Twitter metadata fetch failed")
                return nil
            }
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
            let htmlPreview = String(html.prefix(800))
            let hasTwitterTags = html.contains("twitter:title") || html.contains("twitter:image")
            let hasOGTags = html.contains("og:title") || html.contains("og:image")

            if hasTwitterTags || hasOGTags {
                print("📄 HTML contains meta tags for \(urlString)")
                print("   Twitter tags: \(hasTwitterTags), OG tags: \(hasOGTags)")
            } else {
                print("⚠️  HTML may not contain meta tags for \(urlString)")
                if url.host?.contains("x.com") == true || url.host?.contains("twitter.com") == true {
                    print("📄 X.com response (first 800 chars): \(htmlPreview)")
                }
            }

            let ogData = parseOpenGraph(from: html, url: urlString)

            if ogData.hasData {
                print("✅ Found OpenGraph data for \(urlString)")
                print("   Title: \(ogData.title ?? "none")")
                print("   Image: \(ogData.imageURL ?? "none")")
                print("   Site: \(ogData.siteName ?? "none")")

                // Save to persistent cache (like iMessage does)
                OpenGraphCacheService.shared.cacheData(ogData, for: url)
                print("💾 Saved to persistent cache")
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

    private func fetchTwitterMetadata(for url: URL) async -> OpenGraphData? {
        print("🐦 Fetching Twitter metadata with Twitterbot UA: \(url)")

        // Create a custom URLSession with Twitterbot User-Agent
        // Twitter serves full HTML with meta tags when it sees Twitterbot
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Twitterbot/1.0",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br"
        ]
        let twitterSession = URLSession(configuration: config)

        do {
            let (data, response) = try await twitterSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("   ❌ Not an HTTP response")
                return nil
            }

            print("   📡 HTTP status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("   ❌ HTTP \(httpResponse.statusCode)")
                return nil
            }

            guard let html = String(data: data, encoding: .utf8) else {
                print("   ❌ Failed to decode HTML")
                return nil
            }

            // Check if we got meta tags
            let hasTwitterTags = html.contains("twitter:title") || html.contains("twitter:image")
            let hasOGTags = html.contains("og:title") || html.contains("og:image")

            print("   📄 Got HTML with Twitter tags: \(hasTwitterTags), OG tags: \(hasOGTags)")

            // Parse the HTML for OpenGraph/Twitter card tags
            let ogData = parseOpenGraph(from: html, url: url.absoluteString)

            if ogData.hasData {
                print("   ✅ Successfully extracted Twitter metadata")
                print("      Title: \(ogData.title ?? "none")")
                print("      Description: \(ogData.description?.prefix(100) ?? "none")")
                print("      Image: \(ogData.imageURL ?? "none")")
                return ogData
            } else {
                print("   ⚠️  No OpenGraph data found in HTML")
            }
        } catch {
            print("   ❌ Failed to fetch Twitter metadata: \(error)")
        }

        return nil
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
                    // Filter out Twitter profile pictures
                    let isProfilePic = content.contains("profile_images") || content.contains("_normal")
                    if !isProfilePic {
                        imageURL = content
                    } else {
                        print("   🚫 Skipping profile picture: \(String(content.prefix(100)))")
                    }
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
                    // Filter out Twitter profile pictures
                    let isProfilePic = content.contains("profile_images") || content.contains("_normal")
                    if !isProfilePic {
                        twitterImage = content
                    } else {
                        print("   🚫 Skipping profile picture: \(String(content.prefix(100)))")
                    }
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
