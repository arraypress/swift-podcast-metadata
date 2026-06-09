//
//  PodcastModels.swift
//  PodcastMetadata
//
//  Created by David Sherlock on 2025.
//

import Foundation

/// Metadata about a podcast show.
///
/// ```swift
/// let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/...")
/// print(result.show.name)
/// print(result.show.author)
/// ```
public struct ShowMetadata: Codable, Equatable, Sendable {

    /// The show name.
    public let name: String

    /// The show author/creator.
    public let author: String

    /// The show description.
    public let description: String

    /// The RSS feed URL.
    public let feedUrl: String

    /// The show's artwork/cover URL.
    public let artworkUrl: String?

    /// The show's language code.
    public let language: String?

    /// The Apple Podcasts ID, if available.
    public let applePodcastsId: String?

    /// Show categories/genres.
    public let categories: [String]

    /// Whether the show contains explicit content.
    public let isExplicit: Bool
}

/// Metadata about a specific podcast episode.
///
/// ```swift
/// let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/...")
/// if let episode = result.episode {
///     print(episode.title)
///     print(episode.audioUrl ?? "No audio URL")
///     print(episode.formattedDuration)
/// }
/// ```
public struct EpisodeMetadata: Codable, Equatable, Sendable {

    /// The episode title.
    public let title: String

    /// The episode description (may contain HTML).
    public let description: String

    /// Direct URL to the audio file (mp3/m4a).
    public let audioUrl: String?

    /// Audio file MIME type (e.g., `"audio/mpeg"`, `"audio/x-m4a"`).
    public let audioType: String?

    /// Audio file size in bytes, if available.
    public let audioLength: Int?

    /// Episode duration in seconds.
    public let duration: Int?

    /// Publication date.
    public let publishedAt: Date?

    /// Episode artwork URL (may differ from show artwork).
    public let artworkUrl: String?

    /// Episode GUID from the RSS feed.
    public let guid: String?

    /// Episode number, if available.
    public let episodeNumber: Int?

    /// Season number, if available.
    public let seasonNumber: Int?

    /// Episode type (`"full"`, `"trailer"`, `"bonus"`).
    public let episodeType: String?

    /// Whether the episode contains explicit content.
    public let isExplicit: Bool

    /// The duration formatted as `"M:SS"` or `"H:MM:SS"`.
    ///
    /// Returns `nil` if duration is unavailable.
    public var formattedDuration: String? {
        guard let duration else { return nil }
        let h = duration / 3600
        let m = (duration % 3600) / 60
        let s = duration % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// The publication date formatted as a readable string.
    ///
    /// Returns `nil` if the date is unavailable.
    public var formattedDate: String? {
        guard let date = publishedAt else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    /// The audio file size formatted as a readable string (e.g., `"45.2 MB"`).
    ///
    /// Returns `nil` if the file size is unavailable.
    public var formattedFileSize: String? {
        guard let length = audioLength, length > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(length))
    }
}

/// The result of fetching podcast metadata.
///
/// Contains show information and optionally a matched episode.
///
/// ```swift
/// let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/...")
///
/// print(result.show.name)
/// print(result.episode?.title ?? "No specific episode matched")
/// print(result.episode?.audioUrl ?? "No audio URL")
/// print("Total episodes: \(result.episodes.count)")
/// ```
public struct PodcastResult: Sendable {

    /// The source platform that was used as input.
    public let platform: Platform

    /// Show-level metadata.
    public let show: ShowMetadata

    /// The specific episode that was matched, if a single episode URL was provided.
    public let episode: EpisodeMetadata?

    /// All episodes from the RSS feed (most recent first).
    ///
    /// For large feeds this may be a subset. Use `episode` for the specific matched one.
    public let episodes: [EpisodeMetadata]

    /// The source platform of the input URL.
    public enum Platform: String, Sendable {
        case apple = "apple"
        case spotify = "spotify"
    }
}
