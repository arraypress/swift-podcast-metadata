# Swift Podcast Metadata

A Swift library for fetching podcast metadata and direct audio URLs from Apple Podcasts and Spotify links. Resolves RSS feeds to extract show info, episode details, and downloadable audio files. No API key or authentication required.

## Features

- 🎯 **Simple API** — one `fetch()` call for both Apple Podcasts and Spotify URLs
- 🎵 **Direct audio URLs** — mp3/m4a download links from RSS feeds
- 📊 **Rich metadata** — show name, author, description, artwork, categories
- 📋 **Episode details** — title, description, duration, publish date, season/episode numbers
- 🔄 **Cross-platform** — Spotify links automatically resolve via Apple Podcasts RSS
- 🔒 **No API key required** — uses public iTunes API and Spotify oembed
- 🍎 **Cross-platform** — macOS, iOS, tvOS, watchOS
- ⚡ **Async/await** native — built for modern Swift concurrency
- 🛡️ **Typed error handling** — specific errors for every failure case

## Requirements

- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-podcast-metadata.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Choose version requirements

## Usage

### Fetch from Apple Podcasts

```swift
import PodcastMetadata

// With a specific episode
let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/gb/podcast/the-diary-of-a-ceo/id1291423644?i=1000755033920")

print(result.show.name)           // "The Diary Of A CEO with Steven Bartlett"
print(result.show.author)         // "DOAC"
print(result.episode?.title ?? "")
print(result.episode?.audioUrl ?? "")  // Direct mp3 URL
print(result.episode?.formattedDuration ?? "")

// Show only (no specific episode)
let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/gb/podcast/the-diary-of-a-ceo/id1291423644")
print("Episodes: \(result.episodes.count)")
```

### Fetch from Spotify

Spotify links are automatically cross-referenced with Apple Podcasts to find the RSS audio URL.

```swift
let result = try await PodcastMetadata.fetch("https://open.spotify.com/episode/06Vp1FqjoLVbMdrfrPveok")

print(result.show.name)
print(result.episode?.title ?? "")
print(result.episode?.audioUrl ?? "Spotify exclusive")
```

### Access Episode Audio

```swift
let result = try await PodcastMetadata.fetch(url)

if let episode = result.episode {
    print("Title: \(episode.title)")
    print("Audio: \(episode.audioUrl ?? "N/A")")
    print("Type: \(episode.audioType ?? "N/A")")       // "audio/mpeg"
    print("Size: \(episode.formattedFileSize ?? "N/A")") // "45.2 MB"
    print("Duration: \(episode.formattedDuration ?? "N/A")")
    print("Published: \(episode.formattedDate ?? "N/A")")
}
```

### Browse All Episodes

```swift
let result = try await PodcastMetadata.fetch(url)

for episode in result.episodes.prefix(10) {
    print("\(episode.title) — \(episode.formattedDuration ?? "?")")
    print("  Audio: \(episode.audioUrl ?? "N/A")")
}
```

### Show Metadata

```swift
let result = try await PodcastMetadata.fetch(url)

print("Show: \(result.show.name)")
print("Author: \(result.show.author)")
print("Description: \(result.show.description)")
print("Artwork: \(result.show.artworkUrl ?? "N/A")")
print("Language: \(result.show.language ?? "N/A")")
print("Categories: \(result.show.categories)")
print("Explicit: \(result.show.isExplicit)")
print("RSS: \(result.show.feedUrl)")
```

### Error Handling

```swift
do {
    let result = try await PodcastMetadata.fetch(url)
    print(result.show.name)
} catch PodcastMetadataError.podcastNotFound {
    print("Podcast not found on Apple Podcasts")
} catch PodcastMetadataError.spotifyExclusive(let title) {
    print("\(title) is a Spotify exclusive")
} catch PodcastMetadataError.feedUnavailable {
    print("RSS feed is unavailable")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Models

### `PodcastResult`

The main result struct.

| Property | Type | Description |
|----------|------|-------------|
| `platform` | `Platform` | `.apple` or `.spotify` |
| `show` | `ShowMetadata` | Show-level metadata |
| `episode` | `EpisodeMetadata?` | Matched episode (if specific URL) |
| `episodes` | `[EpisodeMetadata]` | All episodes from RSS feed |

### `ShowMetadata`

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Show name |
| `author` | `String` | Author/creator |
| `description` | `String` | Show description |
| `feedUrl` | `String` | RSS feed URL |
| `artworkUrl` | `String?` | Cover artwork URL |
| `language` | `String?` | Language code |
| `applePodcastsId` | `String?` | Apple Podcasts ID |
| `categories` | `[String]` | Show categories |
| `isExplicit` | `Bool` | Explicit content flag |

### `EpisodeMetadata`

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Episode title |
| `description` | `String` | Episode description |
| `audioUrl` | `String?` | Direct mp3/m4a URL |
| `audioType` | `String?` | MIME type |
| `audioLength` | `Int?` | File size in bytes |
| `formattedFileSize` | `String?` | File size (e.g., "45.2 MB") |
| `duration` | `Int?` | Duration in seconds |
| `formattedDuration` | `String?` | Duration as "M:SS" or "H:MM:SS" |
| `publishedAt` | `Date?` | Publication date |
| `formattedDate` | `String?` | Readable date string |
| `artworkUrl` | `String?` | Episode artwork URL |
| `guid` | `String?` | RSS GUID |
| `episodeNumber` | `Int?` | Episode number |
| `seasonNumber` | `Int?` | Season number |
| `episodeType` | `String?` | "full", "trailer", or "bonus" |
| `isExplicit` | `Bool` | Explicit content flag |

## How It Works

### Apple Podcasts URLs
1. Extracts the podcast ID from the URL
2. Calls Apple's iTunes Lookup API to get the RSS feed URL
3. Fetches and parses the RSS feed (standard RSS 2.0 + iTunes namespace)
4. Matches the specific episode if an episode ID was in the URL

### Spotify URLs
1. Calls Spotify's public oembed endpoint to get the episode title
2. Searches Apple's iTunes API for the matching show
3. Fetches the RSS feed and matches the episode by title
4. Returns the audio URL from the RSS feed

This means Spotify-exclusive podcasts (like Joe Rogan) won't have audio URLs since they aren't on Apple Podcasts. The library will still return the episode title from Spotify but the `audioUrl` will be `nil`.

## Limitations

- **Spotify exclusives** — podcasts only on Spotify won't have audio URLs (no RSS feed available).
- **RSS feed size** — some popular podcasts have very large RSS feeds (hundreds of episodes). Parsing may take a moment.
- **Episode matching** — Spotify → Apple cross-referencing matches by episode title. Titles that differ between platforms may not match.
- **Feed availability** — some podcasts have restricted or private RSS feeds that can't be fetched.

## Testing

```bash
swift test
```

Includes unit tests for RSS parsing and duration formatting, plus integration tests that hit Apple's iTunes API and Spotify's oembed endpoint.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2025.
