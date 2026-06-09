# Swift Podcast Metadata

Fetch podcast metadata and direct audio URLs from Apple Podcasts and Spotify links. `PodcastMetadata` resolves the platform URL to its RSS feed, then returns show details, the matched episode, the full episode list, and downloadable audio URLs. No API key or authentication required.

## Features

- 🎯 **Apple Podcasts & Spotify** — accepts URLs from either platform through one entry point
- 📡 **RSS resolution** — looks up the show via iTunes, then fetches and parses the underlying RSS feed
- 🎧 **Direct audio URLs** — surfaces the downloadable audio file for matched episodes
- 📺 **Show metadata** — name, author, description, artwork, language, categories, and explicit flag
- 📝 **Episode metadata** — title, description, audio URL/type/length, duration, publish date, GUID, episode/season numbers
- 🔢 **Episode list** — returns every episode parsed from the feed, not just the matched one
- 🎯 **Episode matching** — matches the specific Apple/Spotify episode from the URL back to the RSS feed
- 🧮 **Formatted helpers** — `formattedDuration`, `formattedDate`, and `formattedFileSize`
- 🪪 **Platform tagging** — each result is tagged `.apple` or `.spotify`
- 🧱 **Typed errors** — descriptive `PodcastMetadataError` cases, including Spotify-exclusive detection
- ⚡ **Async/await** — a single `async throws` entry point with zero dependencies
- 🔒 **Codable & Sendable** — models are `Codable`, `Equatable`, and `Sendable`

## Requirements

- macOS 13.0+ / iOS 16.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 26.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-podcast-metadata.git", from: "1.0.0")
]
```

## Usage

### Fetching podcast metadata

```swift
import PodcastMetadata

let result = try await PodcastMetadata.fetch("https://podcasts.apple.com/us/podcast/.../id123?i=456")

print(result.show.name)
print(result.show.author)
print(result.episode?.title ?? "")
print(result.episode?.audioUrl ?? "")
print(result.episode?.formattedDuration ?? "")
print("Episodes in feed: \(result.episodes.count)")
print("Platform: \(result.platform.rawValue)")
```

### Spotify links

```swift
// Spotify episodes are matched back to the Apple/RSS feed by title.
let result = try await PodcastMetadata.fetch("https://open.spotify.com/episode/abc123")

if let episode = result.episode {
    print(episode.title)
    print(episode.audioUrl ?? "No public audio URL")  // nil for Spotify exclusives
}
```

### Iterating episodes

```swift
let result = try await PodcastMetadata.fetch(url)

for episode in result.episodes {
    print("\(episode.title) — \(episode.formattedDuration ?? "?")")
    if let size = episode.formattedFileSize {
        print("  \(size)")
    }
}
```

### Error handling

```swift
do {
    let result = try await PodcastMetadata.fetch(url)
    print(result.show.name)
} catch let error as PodcastMetadataError {
    switch error {
    case .invalidUrl:
        print("Provide an Apple Podcasts or Spotify URL")
    case .podcastNotFound:
        print("Podcast not found")
    case .episodeNotFound(let title):
        print("Episode not found: \(title)")
    case .feedUnavailable:
        print("RSS feed unavailable or empty")
    case .feedParsingError:
        print("Failed to parse the RSS feed")
    case .spotifyExclusive(let title):
        print("\"\(title)\" is a Spotify exclusive")
    case .networkError(let message), .parsingError(let message):
        print("Failed: \(message)")
    }
}
```

## How It Works

For Apple Podcasts URLs, the show ID is looked up via the iTunes API to find the RSS feed, which is then fetched and parsed; if the URL names a specific episode, it is matched back into the parsed feed. For Spotify URLs, the episode title is read from Spotify's oembed endpoint, the same show is found on iTunes, and the episode is matched against the RSS feed by title — returning the public audio URL when one exists (`nil` for Spotify exclusives).

## Models

| Model | Description |
|-------|-------------|
| `PodcastResult` | Top-level result: `platform`, `show`, matched `episode`, and all `episodes` |
| `ShowMetadata` | Name, author, description, feed URL, artwork, language, Apple Podcasts ID, categories, explicit flag |
| `EpisodeMetadata` | Title, description, audio URL/type/length, duration, publish date, artwork, GUID, episode/season numbers, type, explicit flag, plus `formattedDuration` / `formattedDate` / `formattedFileSize` |
| `PodcastResult.Platform` | `.apple` or `.spotify` |
| `PodcastMetadataError` | Typed errors with `LocalizedError` descriptions |

## Use Cases

- Resolving a shared podcast link to a downloadable audio file
- Building podcast players or download managers
- Aggregating show and episode metadata across platforms
- Linking Spotify episodes to their RSS equivalents

## Testing

```bash
swift test
```

Tests cover URL parsing, RSS feed parsing, and episode matching.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
