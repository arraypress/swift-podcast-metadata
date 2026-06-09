//
//  PodcastMetadataTests.swift
//  PodcastMetadata
//
//  Created by David Sherlock on 2025.
//

import XCTest
@testable import PodcastMetadata

final class PodcastMetadataTests: XCTestCase {

    // MARK: - Episode Formatting

    func testFormattedDuration() {
        let ep = EpisodeMetadata(
            title: "Test", description: "", audioUrl: nil, audioType: nil,
            audioLength: nil, duration: 1223, publishedAt: nil, artworkUrl: nil,
            guid: nil, episodeNumber: nil, seasonNumber: nil, episodeType: nil, isExplicit: false
        )
        XCTAssertEqual(ep.formattedDuration, "20:23")
    }

    func testFormattedDurationHours() {
        let ep = EpisodeMetadata(
            title: "Test", description: "", audioUrl: nil, audioType: nil,
            audioLength: nil, duration: 7384, publishedAt: nil, artworkUrl: nil,
            guid: nil, episodeNumber: nil, seasonNumber: nil, episodeType: nil, isExplicit: false
        )
        XCTAssertEqual(ep.formattedDuration, "2:03:04")
    }

    func testFormattedDurationNil() {
        let ep = EpisodeMetadata(
            title: "Test", description: "", audioUrl: nil, audioType: nil,
            audioLength: nil, duration: nil, publishedAt: nil, artworkUrl: nil,
            guid: nil, episodeNumber: nil, seasonNumber: nil, episodeType: nil, isExplicit: false
        )
        XCTAssertNil(ep.formattedDuration)
    }

    func testFormattedFileSize() {
        let ep = EpisodeMetadata(
            title: "Test", description: "", audioUrl: nil, audioType: nil,
            audioLength: 47_500_000, duration: nil, publishedAt: nil, artworkUrl: nil,
            guid: nil, episodeNumber: nil, seasonNumber: nil, episodeType: nil, isExplicit: false
        )
        XCTAssertNotNil(ep.formattedFileSize)
    }

    func testFormattedFileSizeNil() {
        let ep = EpisodeMetadata(
            title: "Test", description: "", audioUrl: nil, audioType: nil,
            audioLength: nil, duration: nil, publishedAt: nil, artworkUrl: nil,
            guid: nil, episodeNumber: nil, seasonNumber: nil, episodeType: nil, isExplicit: false
        )
        XCTAssertNil(ep.formattedFileSize)
    }

    func testFormattedDate() {
        let ep = EpisodeMetadata(
            title: "Test", description: "", audioUrl: nil, audioType: nil,
            audioLength: nil, duration: nil, publishedAt: Date(), artworkUrl: nil,
            guid: nil, episodeNumber: nil, seasonNumber: nil, episodeType: nil, isExplicit: false
        )
        XCTAssertNotNil(ep.formattedDate)
    }

    // MARK: - RSS Parser

    func testParseSimpleRSS() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
            <title>Test Podcast</title>
            <itunes:author>Test Author</itunes:author>
            <description>A test podcast</description>
            <language>en</language>
            <itunes:explicit>no</itunes:explicit>
            <itunes:image href="https://example.com/art.jpg"/>
            <item>
                <title>Episode 1</title>
                <description>First episode</description>
                <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" length="5000000"/>
                <itunes:duration>1800</itunes:duration>
                <guid>ep-001</guid>
                <pubDate>Mon, 10 Mar 2025 12:00:00 +0000</pubDate>
                <itunes:episode>1</itunes:episode>
                <itunes:season>1</itunes:season>
                <itunes:episodeType>full</itunes:episodeType>
            </item>
            <item>
                <title>Episode 2</title>
                <description>Second episode</description>
                <enclosure url="https://example.com/ep2.mp3" type="audio/mpeg" length="6000000"/>
                <itunes:duration>25:30</itunes:duration>
                <guid>ep-002</guid>
            </item>
        </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let parser = RSSParser(feedUrl: "https://example.com/feed")
        let feed = try parser.parse(data: data)

        XCTAssertEqual(feed.show.name, "Test Podcast")
        XCTAssertEqual(feed.show.author, "Test Author")
        XCTAssertEqual(feed.show.description, "A test podcast")
        XCTAssertEqual(feed.show.language, "en")
        XCTAssertEqual(feed.show.artworkUrl, "https://example.com/art.jpg")
        XCTAssertFalse(feed.show.isExplicit)

        XCTAssertEqual(feed.episodes.count, 2)

        let ep1 = feed.episodes[0]
        XCTAssertEqual(ep1.title, "Episode 1")
        XCTAssertEqual(ep1.audioUrl, "https://example.com/ep1.mp3")
        XCTAssertEqual(ep1.audioType, "audio/mpeg")
        XCTAssertEqual(ep1.audioLength, 5000000)
        XCTAssertEqual(ep1.duration, 1800)
        XCTAssertEqual(ep1.guid, "ep-001")
        XCTAssertEqual(ep1.episodeNumber, 1)
        XCTAssertEqual(ep1.seasonNumber, 1)
        XCTAssertEqual(ep1.episodeType, "full")
        XCTAssertNotNil(ep1.publishedAt)

        let ep2 = feed.episodes[1]
        XCTAssertEqual(ep2.title, "Episode 2")
        XCTAssertEqual(ep2.duration, 1530) // 25:30
    }

    func testParseDurationFormats() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
            <title>Test</title>
            <item>
                <title>Seconds Only</title>
                <itunes:duration>3600</itunes:duration>
            </item>
            <item>
                <title>MM:SS</title>
                <itunes:duration>45:30</itunes:duration>
            </item>
            <item>
                <title>H:MM:SS</title>
                <itunes:duration>1:30:00</itunes:duration>
            </item>
        </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let parser = RSSParser(feedUrl: "https://example.com/feed")
        let feed = try parser.parse(data: data)

        XCTAssertEqual(feed.episodes[0].duration, 3600)
        XCTAssertEqual(feed.episodes[1].duration, 2730) // 45*60 + 30
        XCTAssertEqual(feed.episodes[2].duration, 5400) // 1*3600 + 30*60
    }

    // MARK: - Error Descriptions

    func testAllErrorsHaveDescriptions() {
        let errors: [PodcastMetadataError] = [
            .invalidUrl,
            .podcastNotFound,
            .episodeNotFound(title: "Test"),
            .feedUnavailable,
            .feedParsingError,
            .spotifyExclusive(title: "Test"),
            .networkError("timeout"),
            .parsingError("bad xml"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Integration Tests (require network)

    func testFetchApplePodcastsDOAC() async throws {
        let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/gb/podcast/the-diary-of-a-ceo-with-steven-bartlett/id1291423644?i=1000755033920")

        XCTAssertEqual(result.platform, .apple)
        XCTAssertFalse(result.show.name.isEmpty)
        XCTAssertFalse(result.show.author.isEmpty)
        XCTAssertNotNil(result.show.feedUrl)
        XCTAssertFalse(result.episodes.isEmpty)

        // Should have matched the specific episode
        XCTAssertNotNil(result.episode)
        XCTAssertNotNil(result.episode?.audioUrl)
        XCTAssertTrue(result.episode?.audioUrl?.contains(".mp3") ?? false)
    }

    func testFetchApplePodcastsShowOnly() async throws {
        let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/gb/podcast/the-diary-of-a-ceo-with-steven-bartlett/id1291423644")

        XCTAssertEqual(result.platform, .apple)
        XCTAssertFalse(result.show.name.isEmpty)
        XCTAssertNil(result.episode) // No specific episode requested
        XCTAssertFalse(result.episodes.isEmpty)

        // First episode should have audio URL
        XCTAssertNotNil(result.episodes.first?.audioUrl)
    }

    func testFetchSpotifyDOAC() async throws {
        let result = try await PodcastMetadata.fetch("https://open.spotify.com/episode/06Vp1FqjoLVbMdrfrPveok")

        XCTAssertEqual(result.platform, .spotify)
        XCTAssertFalse(result.show.name.isEmpty)
        XCTAssertFalse(result.episodes.isEmpty)

        // Should have matched the episode via title cross-reference
        if let episode = result.episode {
            XCTAssertFalse(episode.title.isEmpty)
            XCTAssertNotNil(episode.audioUrl)
        }
    }

    func testFetchSpotifyEpisodeHasAudioUrl() async throws {
        let result = try await PodcastMetadata.fetch("https://open.spotify.com/episode/06Vp1FqjoLVbMdrfrPveok")

        // The DOAC episode should be findable on Apple Podcasts
        if let episode = result.episode {
            XCTAssertNotNil(episode.audioUrl, "Non-exclusive podcast should have an audio URL from RSS")
        }
    }
}
