# Quote of the Day Widget Plan

## Summary

Add a WidgetKit extension in learning-sized phases, keeping Dogeared document-based. The first real widget source will be an explicit “Widget Library” chosen by the user, not “last opened,” because it creates a clearer mental model and avoids a large storage/sync rewrite.

The first two checkpoints are underway: a static `QuoteOfTheDayWidget` target exists, and its provider now separates placeholder, snapshot, and timeline sample entries while still using fake quote data. Future work should build from that target gradually instead of jumping straight to document-backed data.

## Key Decisions

- Keep Dogeared document-based for this feature.
- Do not have the widget open a `.libnotes` document directly.
- Add a small shared quote cache in the existing app group `group.org.brians-brain.grail-diary`.
- Store the selected widget library as bookmark data in app-group defaults so the app can reopen it later.
- Make the widget read only a Codable snapshot cache: quote text, note id, quote key, book title, source library display name, and cache timestamp.
- Make “Quote of the Day” deterministic per local day, selected from the cached quote pool by date-based hashing rather than live randomization.
- Make widget taps deep-link into Dogeared, resolve the selected library bookmark, open the note, and highlight/select the quote text when possible.

## Learning Phases

1. Static widget target
   - Add `DogearedQuoteWidgetExtension` or equivalent WidgetKit target.
   - Implement a minimal `TimelineProvider`, entry type, SwiftUI view, `StaticConfiguration`, and preview.
   - Build and inspect the new target, bundle ID, extension Info.plist, generated scheme, and app embedding.

2. Timeline mechanics
   - Replace static-only behavior with clear placeholder, snapshot, and timeline sample entries.
   - Keep using fake quote data.
   - Build and inspect Xcode previews, simulator widget gallery behavior, and the difference between widget timeline state and normal app state.

3. Shared model and fixture data
   - Add `QuoteOfTheDaySnapshot`, `QuoteWidgetCandidate`, and `QuoteWidgetStore`.
   - Read a fixture snapshot from the app-group container.
   - Do not touch document access yet.

4. Explicit widget library selection
   - Add a “Use This Library for Quote Widget” action in the open library UI.
   - Save selected-library bookmark data and display name in app-group defaults.
   - Publish a quote snapshot from the current `NoteDatabase` using existing quote extraction APIs.
   - Inspect app-group defaults and snapshot JSON after selection.

5. Daily quote selection and refresh
   - Generate the quote deterministically from local day plus the cached quote pool.
   - Build timelines for the next several local midnights.
   - Call `WidgetCenter.shared.reloadTimelines(ofKind:)` only after the selected library cache changes.
   - Test with an injected clock or simulator date changes.

6. Deep link from widget to app
   - Add a URL such as `dogeared://quote-of-the-day?noteId=...&quoteKey=...`.
   - Route the URL in `SceneDelegate`.
   - Resolve the selected library bookmark, open the document, call existing `pushNote(with:selectedText:)`, and fall back to opening the library if the exact quote is unavailable.

7. Widget polish
   - Support `systemSmall` and `systemMedium` first.
   - Show quote text and book title.
   - Omit thumbnails for v1 unless layout remains readable.
   - Use `containerBackground(for: .widget)` and provide placeholder/redacted UI.

## Public Interfaces And Types

- `QuoteOfTheDaySnapshot: Codable, Sendable`
- `QuoteWidgetCandidate: Codable, Sendable`
- `QuoteWidgetStore` for app-group read/write, deterministic daily selection, and cache validation
- `UserDefaults` helpers for app-group suite access and selected widget library bookmark data
- One quote widget deep-link route
- One WidgetKit extension target, eventually linked only to the minimum shared code it needs

## Test Plan

- Unit test deterministic daily quote selection: same day gives same quote, next day can change, empty cache returns empty state.
- Unit test snapshot encoding/decoding and app-group file path construction.
- App integration test or manual smoke: select widget library, verify snapshot contains quote candidates from `promptCollectionPublisher(promptType: .quote, tagged: nil)`.
- Manual widget smoke: placeholder before selection, populated widget after selection, quote changes across injected dates, widget tap opens the right note.
- Run `xcodebuild -scheme "Dogeared Notes" -project LibraryNotes.xcodeproj build`.
- Run `swift test --package-path LibraryNotesCore` if shared model logic lands in `LibraryNotesCore`.

## Current Checkpoint

- `QuoteOfTheDayWidget` target exists.
- `QuoteOfTheDayWidget/QuoteOfTheDayWidget.swift` contains a fake-data WidgetKit implementation with distinct placeholder, snapshot, and timeline entries.
- The placeholder entry is redacted in the widget view.
- The snapshot and timeline entries intentionally use different fake quotes so WidgetKit lifecycle behavior is visible in previews and simulator inspection.
- The app build has validated that `QuoteOfTheDayWidget.appex` embeds in `Dogeared Notes.app/PlugIns`.

## Assumptions

- The first widget supports iOS/iPadOS small and medium families only.
- Mac Catalyst widget behavior is not required for the first pass.
- The widget cache is a projection of the selected document, not the source of truth.
- iCloud sync continues to be handled by the existing document model; widget data updates when the app opens or saves/publishes the selected library.
- SwiftFormat is used only if Swift edits need mechanical formatting; SwiftLint is not required.
