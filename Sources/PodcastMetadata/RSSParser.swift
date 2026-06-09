//
//  RSSParser.swift
//  PodcastMetadata
//
//  Created by David Sherlock on 2025.
//

import Foundation

/// Parsed RSS feed containing show info and episodes.
struct ParsedFeed: Sendable {
    let show: ShowMetadata
    let episodes: [EpisodeMetadata]
}

/// Parses podcast RSS feeds into structured metadata.
///
/// Uses Foundation's `XMLParser` for cross-platform compatibility.
/// Handles standard RSS 2.0 tags and iTunes podcast namespace extensions.
final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: - State

    private var episodes: [EpisodeMetadata] = []
    private var currentElement = ""
    private var currentText = ""
    private var isInItem = false
    private var isInChannel = false
    private var isInImage = false

    // Channel-level fields
    private var showName = ""
    private var showAuthor = ""
    private var showDescription = ""
    private var showLanguage: String?
    private var showArtworkUrl: String?
    private var showCategories: [String] = []
    private var showExplicit = false
    private var feedUrl: String

    // Episode-level fields
    private var epTitle = ""
    private var epDescription = ""
    private var epAudioUrl: String?
    private var epAudioType: String?
    private var epAudioLength: Int?
    private var epDuration: Int?
    private var epPubDate: String?
    private var epArtworkUrl: String?
    private var epGuid: String?
    private var epNumber: Int?
    private var epSeason: Int?
    private var epType: String?
    private var epExplicit = false

    // MARK: - Init

    init(feedUrl: String) {
        self.feedUrl = feedUrl
        super.init()
    }

    // MARK: - Parse

    /// Parses RSS XML data into a `ParsedFeed`.
    func parse(data: Data, applePodcastsId: String? = nil) throws -> ParsedFeed {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw PodcastMetadataError.feedParsingError
        }

        let show = ShowMetadata(
            name: showName.trimmingCharacters(in: .whitespacesAndNewlines),
            author: showAuthor.trimmingCharacters(in: .whitespacesAndNewlines),
            description: showDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            feedUrl: feedUrl,
            artworkUrl: showArtworkUrl,
            language: showLanguage,
            applePodcastsId: applePodcastsId,
            categories: showCategories,
            isExplicit: showExplicit
        )

        return ParsedFeed(show: show, episodes: episodes)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "channel" {
            isInChannel = true
        } else if elementName == "item" {
            isInItem = true
            resetEpisodeFields()
        } else if elementName == "image" && !isInItem {
            isInImage = true
        }

        // Enclosure tag (audio file)
        if elementName == "enclosure" && isInItem {
            epAudioUrl = attributes["url"]
            epAudioType = attributes["type"]
            if let lengthStr = attributes["length"] {
                epAudioLength = Int(lengthStr)
            }
        }

        // iTunes image (show or episode level)
        if elementName == "itunes:image" {
            if let href = attributes["href"] {
                if isInItem {
                    epArtworkUrl = href
                } else if isInChannel {
                    showArtworkUrl = href
                }
            }
        }

        // iTunes category
        if elementName == "itunes:category" && !isInItem {
            if let text = attributes["text"] {
                showCategories.append(text)
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentText += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "item" {
            // Build and store episode
            let episode = buildEpisode()
            episodes.append(episode)
            isInItem = false
        } else if elementName == "image" {
            isInImage = false
        } else if elementName == "channel" {
            isInChannel = false
        }

        if isInItem {
            // Episode-level fields
            switch elementName {
            case "title": epTitle = trimmed
            case "description": epDescription = trimmed
            case "guid": epGuid = trimmed
            case "pubDate": epPubDate = trimmed
            case "itunes:duration": epDuration = parseDuration(trimmed)
            case "itunes:episode": epNumber = Int(trimmed)
            case "itunes:season": epSeason = Int(trimmed)
            case "itunes:episodeType": epType = trimmed
            case "itunes:explicit":
                epExplicit = trimmed.lowercased() == "yes" || trimmed.lowercased() == "true"
            default: break
            }
        } else if isInChannel && !isInImage {
            // Channel-level fields
            switch elementName {
            case "title": showName = trimmed
            case "description": if showDescription.isEmpty { showDescription = trimmed }
            case "itunes:author": showAuthor = trimmed
            case "itunes:summary": if showDescription.isEmpty { showDescription = trimmed }
            case "language": showLanguage = trimmed
            case "itunes:explicit":
                showExplicit = trimmed.lowercased() == "yes" || trimmed.lowercased() == "true"
            default: break
            }
        }

        currentText = ""
    }

    // MARK: - Helpers

    private func resetEpisodeFields() {
        epTitle = ""
        epDescription = ""
        epAudioUrl = nil
        epAudioType = nil
        epAudioLength = nil
        epDuration = nil
        epPubDate = nil
        epArtworkUrl = nil
        epGuid = nil
        epNumber = nil
        epSeason = nil
        epType = nil
        epExplicit = false
    }

    private func buildEpisode() -> EpisodeMetadata {
        EpisodeMetadata(
            title: epTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: epDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            audioUrl: epAudioUrl,
            audioType: epAudioType,
            audioLength: epAudioLength,
            duration: epDuration,
            publishedAt: parseDate(epPubDate),
            artworkUrl: epArtworkUrl,
            guid: epGuid,
            episodeNumber: epNumber,
            seasonNumber: epSeason,
            episodeType: epType,
            isExplicit: epExplicit
        )
    }

    /// Parses iTunes duration strings: `"1223"` (seconds), `"20:23"` (MM:SS), or `"1:20:23"` (H:MM:SS).
    private func parseDuration(_ value: String) -> Int? {
        // Pure seconds
        if let seconds = Int(value) {
            return seconds
        }

        // MM:SS or H:MM:SS
        let parts = value.components(separatedBy: ":")
        if parts.count == 2 {
            let m = Int(parts[0]) ?? 0
            let s = Int(parts[1]) ?? 0
            return m * 60 + s
        } else if parts.count == 3 {
            let h = Int(parts[0]) ?? 0
            let m = Int(parts[1]) ?? 0
            let s = Int(parts[2]) ?? 0
            return h * 3600 + m * 60 + s
        }

        return nil
    }

    /// Parses RFC 2822 date strings from RSS feeds.
    private func parseDate(_ dateStr: String?) -> Date? {
        guard let dateStr else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try common RSS date formats
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }

        // Try ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateStr) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: dateStr)
    }
}
