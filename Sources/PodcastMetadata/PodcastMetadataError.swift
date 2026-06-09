//
//  PodcastMetadataError.swift
//  PodcastMetadata
//
//  Created by David Sherlock on 2025.
//

import Foundation

/// Errors that can occur when fetching podcast metadata.
public enum PodcastMetadataError: Error, LocalizedError, Equatable, Sendable {

    /// The URL is not a supported podcast platform URL.
    case invalidUrl

    /// Could not find the podcast on Apple Podcasts.
    case podcastNotFound

    /// Could not find the specific episode in the RSS feed.
    case episodeNotFound(title: String)

    /// The RSS feed could not be fetched or is empty.
    case feedUnavailable

    /// The RSS feed could not be parsed as valid XML.
    case feedParsingError

    /// A Spotify episode could not be matched to an Apple Podcasts episode.
    ///
    /// This typically happens with Spotify-exclusive podcasts.
    case spotifyExclusive(title: String)

    /// A network request failed.
    case networkError(String)

    /// Failed to parse response data.
    case parsingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid podcast URL. Provide an Apple Podcasts or Spotify episode/show URL."
        case .podcastNotFound:
            return "Podcast not found on Apple Podcasts."
        case .episodeNotFound(let title):
            return "Episode \"\(title)\" not found in the RSS feed."
        case .feedUnavailable:
            return "The podcast RSS feed is unavailable or empty."
        case .feedParsingError:
            return "Failed to parse the podcast RSS feed."
        case .spotifyExclusive(let title):
            return "\"\(title)\" appears to be a Spotify exclusive and is not available on Apple Podcasts."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        }
    }
}
