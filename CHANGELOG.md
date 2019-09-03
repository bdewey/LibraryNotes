# Changelog

## [0.7.1] - 2019-09-03

### Changed

- Eliminated "Cancel" button on study view; just use swipe-to-dismiss

### Fixed

- Cloze cards now manage attributes correctly and no longer clobber paragraph attributes
- Vocabulary dialog no longer uses two columns on iPad
- All saved templates now decode properly
- "Highlight" menu command now works

## [0.7.0] - 2019-09-02

### Added

- New page type! A vocabulary list.
- Internals: The ability to store and change "naked" properties

### Changed

- Internals: QuoteTemplate and ClozeTemplate use single-value containers

### Removed

- CardTemplateSerializationWrapper and related tests
- MarkdownParseable protocol
- String `identifier` property on Challenge

## [0.6.2] - 2019-08-29

### Fixed

- Bug with computing the next date in spaced repetition

## [0.6.1] - 2019-08-26

### Fixed

- Swipe actions are back!
- Always try to load the defalut document in the simulator

## [0.6.0] - 2019-08-24

### Added

- Document browser
- Remembers the most recent open document and page
- If no recent document, opens "archive.notebundle" (important for onboarding & simulator)
- Added UserDefault property wrapper to make it easier to persist data

### Changed

- Instead of an empty view controller, use a blank document page

## [0.5.0] - 2019-08-20

### Added

- Compiles with Xcode 11 Beta 6 and runs on iOS 13 Beta 7

### Changed

- When you delete a page, it gets removed from the index AND from the detail view (if it was the page you were looking at)
- The TextEditViewController now uses the readableContentGuide to adjust the margins of the text.
- Use an empty view controller when you haven't explicitly selected a page

### Fixed

- The document list was filtered even when search wasn't active

## [0.4.0] - 2019-08-12

### Added

- Mac support via Catalyst
- Full-text search

## [0.3.0] - 2019-08-07

### Changed

- Faster typing propagation between master & detail view
- Keep rows highlighted in the detail view

## [0.2.0] - 2019-08-03

### Changed

- Shows all available hashtags when nothing in the search bar
- When you click "clear" on the search bar and there is an active search, it goes to the non-filtered state instead of the "active search" state
- Refined split view behavior: on iPhone, don't start by looking at an empty document. On iPad, prefer to keep everything visible.

### Fixed

- "New page" button didn't use the detail view controller

## [0.1.0] - 2019-08-02

### Added

- First explicitly tracked version!
- Dark Mode support
- Dynamic Type support

### Changed

- iOS 13 only
- Split View Controller
- Interact with hashtags through a search interface, not a menu
- Got rid of Material Design
