# Changelog

## Unreleased

### Added

- Support for hierarchical hashtags! Hello, #books/2021

## [0.35.0] - 2021-01-01 Happy New Year!

### Added

- Version string at the bottom of the primary view controller
- We save logs to a file to help with missing pages.

## [0.34.0] - 2020-12-31

### Added

- A share extension, plus UI that lets you browse web pages from inside the app.

## [0.33.0] - 2020-12-23

### Changed

- **Significant** refactor / cleanup of the data layer. Bug chance is **EXTREMELY** high. However, the app is now in a good place for "multi-content notes" (inspired by Wikipedia) which will help move into new scenarios, like explicitly capturing notes "about" things.

## [0.32.0] - 2020-12-02

### Fixed

- Detect & fix corrupt full text indexes. (How'd it get corrupt in the first place? Not sure.)

## [0.31.0] - 2020-11-26 Happy Thanksgiving!

### Changed

- Apache license for this project
- New material gets scheduled for about 4 days in the future for review
- Tests pass again
- Cleaned up a bunch of warnings, reorganized & refactored a bunch of code.

## [0.30.0] - 2020-11-23

### Changed

- Internal rewrite to clean up the string classes and move the ParsingTextStorage implementation to Objective-C so it can avoid bridging `string` when working with TextKit.
- Rename `NewNode` to `SyntaxTreeNode`

## [0.29.0] - 2020-11-21

### Changed

- No more Cocoapods! Open the project file, not hte workspace.
- The project now uses Swift Package Manager to manage SnapKit

### Removed

- No more Yams pod.
- No more CocoaLumberjack pod.

### Fixed

- Inline styles applied to a single character didn't get applied

## [0.28.0] - 2020-11-18

### Changed

- **Huge** internal rewrite, based on piece tables and incremental packrat parsing of a PEG grammar. Bug risk: **extremely high.**
- Follows the UI convention of Apple Notes. When collapsed, there is a "compose" button in the toolbar on all columns. When expanded, the "compose" button is in the navigation bar of the detail column.

### Fixed

- Toolbars show consistently
- If there are no hashtags, no longer shows a "Tags" header with no content

## [0.26.0] - 2020-10-20

### Changed

- iOS 14!
- Three column / sidebar UI
- Many buttons moved to the toolbar

## [0.25.1] - 2020-10-16

### Changed

- Built with Xcode 12.1 GM

## [0.25.0] - 2020-07-03

### Changed

- Builds with Xcode 12 beta
- Swipe gesture is much more accepting

## [0.24.1] - 2020-06-22

Nothing changed! Just a version bump to refresh the TestFlight build.

## [0.24.0] - 2020-03-21

### Changed

- We have a review button in the list, not a bar button item.
- The new review button says how man items there are to review.
- Studying is now a full screen affair with translucent backgrounds.
- Consistent right alignment
- Got rid of the "days since modified" counter

## [0.23.0] - 2020-03-15

### Added

- Show the title in the page title bar

### Changed

- Got rid of a bunch of migration code -- there's only one file that matters and it's up to date.

### Fixed

- Nav bar color on iPad now uses the color scheme
- New document creation logic now fixed
- The split view controller button is back!
- If you delete the visible page, once again you see a blank page

### Removed

- All stuff about vocabulary challenges. This is no longer an Anki-like program; its focus is _writing_.

## [0.22.0] - 2020-03-14

### Changed

- New branding! The app is now called Grail Diary and has a color scheme inspired by an old leather-bound book.

## [0.21.1] - 2020-03-08

### Changed

- The "age indicator" label now updates once per minute to a rounded-down value of the last modified time
- The study session due date updates with the passage of time and with app foregrounding

## [0.21.0] - 2020-03-07

### Added

- Schema change: Use update sequence numbers to drive merging
- Not sure if it's needed, but pull-to-refresh!

## [0.20.1] - 2020-03-07

### Changed

- Don't actually write document content unless there are changes; prevents unneeded uploads to iCloud (and therefore might reduce conflict chances?).

## [0.20.0] - 2020-03-04

### Added

- Can merge notes and challenges using a last-writer-wins policy

### Changed

- Use UIDocument instead of NSFilePresenter / NSFileCoordinator directly. I now think it's safe to keep the document open when backgrounding
- Got rid of the "hashtag" table; we just need "noteHashtag".

## [0.19.0] - 2020-01-26

### Changed

- New challenges are now scheduled around 4 days in advance (fuzzed) ... the thought being *you just created this content so you remember it now*. But will you still remember it in a few days?
- We look for all challenges that would be due today... so it doesn't matter if you study in the morning or the night.

## [0.18.1] - 2020-01-24

### Fixed

- Crash on manipulating UserDefaults. Introduced when I moved to Xcode 11.3.1 and didn't show up in the simulator because I don't use the UserDefault file-saving path.

## [0.18.0] - 2020-01-24

### Changed

- Compiles with Xcode 11.3.1
- Database schema now uses a FlakeID to encapsulate creation time & creation device for notes & challenge templates. If I ever write statistics & merge, this'll be helpful.

## [0.17.1] - 2020-01-15

### Fixed

- Fixed bug where templates would not properly load, blocking everything with the note.

## [0.17.0] - 2020-01-14

### Removed

- Goodbye, custom notebundle format.

## [0.16.0] - 2020-01-14

### Added

- Anki-inspired spaced repetition scheduler.
- *Challenge template stability*. Challenges created from parsing markdown don't have an identity. We now have code that looks for identical-or-close templates from a prior version of a `Note` to preserve the identity of that template.

### Changed

- Related challenges are "buried" -- you won't get challenges from the same template in the same day.
- Significant refactor of `ChallengeTemplate`. They are no longer `Codable` -- instead they are `RawRepresentable`.

## [0.15.0] - 2020-01-12

### Added

- Commonplace Book now supports a new file format: .notedb, which is a single sqlite file. It is compatible with iCloud Document Storage though.
- Database storage is the default for new documents.
- Database storage has full-text search!

## [0.14.0] - 2020-01-02

### Changed

- Internally, storage now goes through a `NoteStorage` protocol instance. This is the abstraction layer that will let me experiment with a sqlite file format.

## [0.13.0] - 2019-09-28

### Changed

- Made `NoteArchiveDocument.studySession` async to not block typing

### Fixed

- Images can now appear in Q&A cards.

## [0.12.0] - 2019-09-20

### Added

- `CodeSpan` support

### Changed

- Formatting for block quotes

## [0.11.0] - 2019-09-16

### Added

- `QuestionAndAnswer` node for parsing Q&A lines in minimarkdown
- Typing support for question-and-answer format
- `QuestionAndAnswerTemplate` for creating Q&A challenges

## [0.10.0] - 2019-09-14

### Changed

- Tightened up the animation transitions for `TwoSidedCard`
- Polished spacing between card text and attribution for quotes & clozes
- No longer slide up the DocumentListViewController
- No more "Done" button when studying. Swipe-to-dismiss saves on device and discards in simulator.
- Stop using large title, as it doesn't have italics.

## [0.9.0] - 2019-09-11

### Added

- Image search & images for vocabulary cards

## [0.8.1] - 2019-09-04

### Fixed

- Initial color wash is correct on the iPad study view

### Removed

- DocumentCache protocol -- left over from when each page was a different document

## [0.8.0] - 2019-09-03

### Changed

- Swipe-to-score
- Study view uses a progress bar
- Use the readable size guide to set the width of the cards
- Round corners

### Fixed

- Quote cards use a bigger "context" font & kern, consistent with clozes

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
