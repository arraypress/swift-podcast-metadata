//
//  PodcastMetadata.swift
//  PodcastMetadata
//
//  Created by David Sherlock on 2025.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetch metadata and audio URLs from podcasts on Apple Podcasts and Spotify.
///
/// Resolves podcast RSS feeds to extract show info, episode metadata, and
/// direct audio file URLs (mp3/m4a). No API key or authentication required.
///
/// ## Quick Start
///
/// ```swift
/// import PodcastMetadata
///
/// // Apple Podcasts URL
/// let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/gb/podcast/the-diary-of-a-ceo/id1291423644?i=1000755033920")
/// print(result.show.name)
/// print(result.episode?.title ?? "")
/// print(result.episode?.audioUrl ?? "")
///
/// // Spotify URL (cross-references with Apple Podcasts RSS)
/// let result = try await PodcastMetadata.fetch("https://open.spotify.com/episode/06Vp1FqjoLVbMdrfrPveok")
/// print(result.episode?.audioUrl ?? "Spotify exclusive")
/// ```
///
/// ## How It Works
///
/// **Apple Podcasts URLs:**
/// 1. Extracts the podcast ID from the URL
/// 2. Calls Apple's iTunes Lookup API to get the RSS feed URL
/// 3. Fetches and parses the RSS feed for show + episode metadata
/// 4. Matches the specific episode if an episode ID was in the URL
///
/// **Spotify URLs:**
/// 1. Calls Spotify's oembed endpoint to get the episode title
/// 2. Searches Apple's iTunes API for the same show
/// 3. Fetches the RSS feed and matches the episode by title
/// 4. Returns the audio URL from the RSS feed (nil for Spotify exclusives)
public enum PodcastMetadata {

    // MARK: - Configuration

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    // MARK: - Public API

    /// Fetches podcast metadata from an Apple Podcasts or Spotify URL.
    ///
    /// ```swift
    /// let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/...")
    ///
    /// print(result.show.name)
    /// print(result.show.author)
    /// print(result.episode?.title ?? "")
    /// print(result.episode?.audioUrl ?? "")
    /// print(result.episode?.formattedDuration ?? "")
    /// print("Episodes in feed: \(result.episodes.count)")
    /// ```
    ///
    /// - Parameter url: An Apple Podcasts or Spotify podcast/episode URL.
    /// - Throws: ``PodcastMetadataError`` if metadata cannot be retrieved.
    /// - Returns: A ``PodcastResult`` with show info, matched episode, and all episodes.
    public static func fetch(_ url: String) async throws -> PodcastResult {
        let cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanUrl.contains("podcasts.apple.com") {
            return try await fetchFromApple(url: cleanUrl)
        } else if cleanUrl.contains("open.spotify.com") || cleanUrl.contains("spotify.com") {
            return try await fetchFromSpotify(url: cleanUrl)
        } else {
            throw PodcastMetadataError.invalidUrl
        }
    }

    // MARK: - Apple Podcasts Flow

    private static func fetchFromApple(url: String) async throws -> PodcastResult {
        // Extract podcast ID and optional episode ID from URL
        let podcastId = try extractApplePodcastId(from: url)
        let episodeId = extractAppleEpisodeId(from: url)

        // Get RSS feed URL from iTunes Lookup API
        let (feedUrl, iTunesShow) = try await lookupApplePodcast(id: podcastId)

        // Fetch and parse RSS feed
        let feed = try await fetchAndParseFeed(url: feedUrl, applePodcastsId: podcastId)

        // Match specific episode if episode ID was provided
        var matchedEpisode: EpisodeMetadata? = nil
        if let episodeId {
            // Apple episode IDs aren't in RSS, so match by searching iTunes episode lookup
            matchedEpisode = try await matchAppleEpisode(
                episodeId: episodeId,
                episodes: feed.episodes,
                podcastId: podcastId
            )
        }

        return PodcastResult(
            platform: .apple,
            show: feed.show,
            episode: matchedEpisode,
            episodes: feed.episodes
        )
    }

    /// Matches an Apple episode ID to an RSS episode by looking up the episode title via iTunes.
    private static func matchAppleEpisode(episodeId: String, episodes: [EpisodeMetadata], podcastId: String) async throws -> EpisodeMetadata? {
        // Try iTunes lookup for the specific episode to get its title
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(episodeId)&entity=podcastEpisode") else { return nil }

        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let episode = results.first(where: { ($0["wrapperType"] as? String) == "podcastEpisode" }),
              let episodeTitle = episode["trackName"] as? String else {
            // Fallback: return the most recent episode
            return episodes.first
        }

        // Match by title (fuzzy: lowercase, trimmed)
        let normalized = episodeTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return episodes.first(where: {
            $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized
        }) ?? episodes.first(where: {
            $0.title.lowercased().contains(normalized) || normalized.contains($0.title.lowercased())
        })
    }

    // MARK: - Spotify Flow

    private static func fetchFromSpotify(url: String) async throws -> PodcastResult {
        // Get episode title from Spotify oembed
        let spotifyData = try await fetchSpotifyOembed(url: url)

        // Search iTunes for the show
        let showName = extractShowNameFromSpotifyTitle(spotifyData.title)
        let (feedUrl, podcastId) = try await searchApplePodcasts(query: showName)

        // Fetch and parse RSS feed
        let feed = try await fetchAndParseFeed(url: feedUrl, applePodcastsId: podcastId)

        // Match episode by title
        let episodeTitle = spotifyData.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedEpisode = feed.episodes.first(where: {
            $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == episodeTitle
        }) ?? feed.episodes.first(where: {
            $0.title.lowercased().contains(episodeTitle) || episodeTitle.contains($0.title.lowercased())
        })

        return PodcastResult(
            platform: .spotify,
            show: feed.show,
            episode: matchedEpisode,
            episodes: feed.episodes
        )
    }

    // MARK: - Spotify Oembed

    private struct SpotifyOembed {
        let title: String
        let thumbnailUrl: String?
    }

    private static func fetchSpotifyOembed(url: String) async throws -> SpotifyOembed {
        let cleanUrl = url.components(separatedBy: "?").first ?? url
        let encoded = cleanUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanUrl
        guard let oembedUrl = URL(string: "https://open.spotify.com/oembed?url=\(encoded)") else {
            throw PodcastMetadataError.invalidUrl
        }

        var request = URLRequest(url: oembedUrl)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw PodcastMetadataError.networkError("Spotify oembed HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String else {
            throw PodcastMetadataError.parsingError("Invalid Spotify oembed response")
        }

        return SpotifyOembed(
            title: title,
            thumbnailUrl: json["thumbnail_url"] as? String
        )
    }

    // MARK: - Apple iTunes API

    private static func lookupApplePodcast(id: String) async throws -> (feedUrl: String, showData: [String: Any]?) {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&entity=podcast") else {
            throw PodcastMetadataError.parsingError("Invalid iTunes lookup URL")
        }

        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let feedUrl = first["feedUrl"] as? String else {
            throw PodcastMetadataError.podcastNotFound
        }

        return (feedUrl, first)
    }

    private static func searchApplePodcasts(query: String) async throws -> (feedUrl: String, podcastId: String?) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=podcast&limit=5") else {
            throw PodcastMetadataError.parsingError("Invalid iTunes search URL")
        }

        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let feedUrl = first["feedUrl"] as? String else {
            throw PodcastMetadataError.podcastNotFound
        }

        let podcastId = (first["collectionId"] as? Int).map { String($0) }
        return (feedUrl, podcastId)
    }

    // MARK: - RSS Feed

    private static func fetchAndParseFeed(url: String, applePodcastsId: String?) async throws -> ParsedFeed {
        guard let feedUrl = URL(string: url) else {
            throw PodcastMetadataError.feedUnavailable
        }

        var request = URLRequest(url: feedUrl)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw PodcastMetadataError.feedUnavailable
        }

        if data.isEmpty {
            throw PodcastMetadataError.feedUnavailable
        }

        let parser = RSSParser(feedUrl: url)
        return try parser.parse(data: data, applePodcastsId: applePodcastsId)
    }

    // MARK: - URL Parsing

    /// Extracts the Apple Podcasts show ID from a URL.
    ///
    /// Handles: `https://podcasts.apple.com/gb/podcast/show-name/id1291423644`
    private static func extractApplePodcastId(from url: String) throws -> String {
        guard let regex = try? NSRegularExpression(pattern: "id(\\d+)", options: []) else {
            throw PodcastMetadataError.invalidUrl
        }

        let range = NSRange(url.startIndex..., in: url)
        guard let match = regex.firstMatch(in: url, range: range),
              let idRange = Range(match.range(at: 1), in: url) else {
            throw PodcastMetadataError.invalidUrl
        }

        return String(url[idRange])
    }

    /// Extracts the episode ID from an Apple Podcasts URL query parameter.
    ///
    /// Handles: `?i=1000755033920`
    private static func extractAppleEpisodeId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let episodeId = urlComponents.queryItems?.first(where: { $0.name == "i" })?.value else {
            return nil
        }
        return episodeId
    }

    /// Attempts to extract a show name from a Spotify episode title.
    ///
    /// Many podcast episodes have titles like `"#2466 - Francis Foster"` which
    /// don't contain the show name. In those cases, we fall back to searching
    /// with the full title and hope iTunes matches the show.
    private static func extractShowNameFromSpotifyTitle(_ title: String) -> String {
        // The title is the episode title, not the show name.
        // We'll search iTunes with it and hope the show appears.
        // This works because iTunes search is fuzzy and podcast episodes
        // often contain the show name in search results.
        return title
    }
}
