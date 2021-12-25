# Changelog

## Unreleased

### Added

- Ability to group books by year read

### Fixed

- Bugs with list handling

## [1.1.0]

### Added

- Support for large libraries (9000+ books)
- Error dialog on import errors
- Simple UI tests

### Fixed

- Error importing LibraryThing JSON when date wasn't specified
- Creating new document sometimes didn't work (just in debugger?)
- Bug where adding a book rating would delete changes to notes made in that edit session
- Miscellaneous UI bugs

## [1.0.0] - 2021-09-21

**This is it! Finally released on the app store!**

- Provide "starter content" -- information about some Standard Ebooks (https://standardebooks.org)
- Updated the welcome content
- Feedback email goes to librarynotesapp@gmail.com and does not include log files (unless you're in TestFlight)
- Simplified import screen

## [0.56.0-beta] - 2021-09-10

Trying a new brand! **Library Notes**

### Added

- Ability to import another database

### Fixed

- Use the version 0.4 of `KeyValueCRDT` for proper merging of different documents
- Background color changing when there are no search results
- When importing from LibraryThing / Goodreads, properly index the book metadata

## [0.55.0-beta] - 2021-09-05

- Rebranded as **Bookish Notes**

### Added

- "Send feedback" menu option

### Fixed

- File open performance
- Flicker on file open
- Rebuilt with a proper Google Books API key

## [0.54.0-beta] - 2021-09-04

### Added

- Unified interface for searching for books and editing book details
- "Experimental features" setting that controls the Import Kindle Highlights feature.

### Fixed

- Bug where study sessions couldn't be saved

## [0.53.0-beta] - 2021-08-29

### Added

- New look-and-feel that's more "iOS Standard"

## [0.52.1-beta] - 2021-08-24

### Fixed

- Barcode scanner orientation

## [0.52.0-beta] - 2021-08-22

### Added

- Ability to edit book details
- Barcode scanner for book search

### Fixed

- Pull-to-refresh does something again.
- Items that were in a non-default folder (e.g., "currently reading") were no longer showing up in the document list.

## [0.51.3-beta] - 2021-08-15

### Fixed

- Study session generation is no longer a CPU hotspot
- Generating cover images is no longer a CPU hotspot

## [0.51.2-beta] - 2021-08-14

### Fixed

- Linked a new version of TextMarkupKit to resolve memory leaks
- Brought back the version string in the structure view controller

## [0.51.0-beta] - 2021-08-14

### Changed

- **Major** iOS 15 only
- When launching into collapsed environments (e.g., an iPhone), we no longer show a single blank note as the opening screen. Instead, we will show the document list.

### Added

- **Major** Support for a new file format: `.kvcrdt`. This should result in much more reliable file merging of offline changes. 
- Catpure text from camera on phones that support it

### Fixed

- Deleting all text no longer crashes
- Note titles are derived from Books, if present, otherwise from the first line of Markdown.
- Memory leaks of `SavingTextEditViewController` and `TextEditViewController`

### Removed

- The share extension.

## [0.50.0] - 2021-07-13

### Changed

- **Major** The app can now track your reading history with individual books, and it uses that information to update whether the book is "want to read" / "currently reading" / "read." These categories are also now groupings in the document list rather than different folders.
- Standard star rating
- Changed the appearance of the book headers
- Book-related utility code has been moved to a stand-alone library, [BookKit](https://github.com/bdewey/BookKit).
- Updated to Version 0.2 of [SpacedRepetitionScheduler](https://github.com/bdewey/SpacedRepetitionScheduler).

### Fixed

- Improper use of cell registration (Thanks, Xcode 13!)
- Broken formatting when I moved to TextMarkupKit
- List-flashing-while-typing
- Performance: Added an image cache for document thumbnails

## [0.49.0] - 2021-06-25

### Changed

- Use https://github.com/bdewey/TextMarkupKit for core parsing

### Added

- Can export a book list in CSV format
- Can import a Goodreads CSV file
- When the app detects that it needs to merge versions of the file, saves copies of both versions in a temporary directory first for debugging.

### Fixed

- Bulleted & numbered lists are no longer in crazy-hard-to-read color.

## [0.48.0] - 2021-06-02

### Added

- *Tons* of improvements around importing LibraryThing content
- Book pages now get a dedicated slide-away header with title, author, and cover image.
- We can sort by title, author, create date, and modified date

### Fixed

- Cover images weren't getting inserted into brand new notes
- Prevent the note list from flashing while typing on non-compact layouts
- Note UI didn't show recently entered text on background/restore
- If you delete an image from a note, it disappears from the note list
- Miscellaneous typing bugs

## [0.47.0] - 2021-05-22

### Added

- Display a random selection of quotes from the selected books.

## [0.46.0] - 2021-05-07

### Changed

- The app now uses a book-oriented navigation structure instead of a note-oriented navigation structure

### Fixed

- When you create new notes, they are placed inside the container you are currently viewing.

## [0.45.0] - 2021-04-02 No Fooling

### Fixed

- Fixed some subtle bugs deep in the parsing code that could lead to crashes and nonsensical parsing. There might be a perf cost to this, but "accuracy" is more important than "speed"! (In general many of my optimizations in parsing seem a source of bugs & instability, and I wonder if I optimized prematurely when I rewrote with a focus on measuring performance at each step.)
- Fixed a bug computing the "text replacement change in length" that exhibited itself in, guess what, node reuse through memoization and incremental parsing.
- Fixed a bug where the hashtag suggestion UI wouldn't appear

## [0.44.0] - 2021-03-12 Happy birthday to me!

### Added

- Support for Unicode / Emoji throughout the editing surface, including #hashtags
- Import your Kindle hightlights straight from Amazon!

### Changed

- Faster when making edits in large files. This involved core changes to building the parse syntax tree & attributed string attributes.

## Fixed

- Swiping left/right is no longer as finicky
- All fonts were 17.0 points, irrespective of text style.
- If there wasn't a cloze hint, the answer was actually visible. Turns out making the foreground color equal the background color does not make the text invisible *if* the color is semitransparent. The layering winds up giving the text a different alpha value than the background.

## [0.43.0] - 2021-02-14 Happy Valentine's Day!

### Added

- Google Books integration! You can either add book details to an existing note or create a new note based upon a book.

### Changed

- Stop the "hide on swipe" behavior for the note view

### Fixed

- Deleted notes no longer show up in the hashtag views

## [0.42.0] - 2021-02-13

### Added

- Support for images! You can paste images into your notes. Not sure about overall efficiency but I want to start playing with it.

## [0.41.0] - 2021-02-07

### Added

- You can add a summary to notes, which will show up in the notes view.
- New "rotate and shrink" effect in the study view
- Quote formatting button

### Fixed

- Editing notes always moved them to the "Notes" folder. Now they stay where they started.
- When you are looking at a particular folder and create a new note, it will be in that folder. (Even the trash!)
- When opening a document for the first time, the UI would not properly display

## [0.40.0] - 2021-01-23

### Added

- Folder structure! Items from the share extension go to "Inbox." You can move stuff to "Archive" if you don't want it cluttering the tag list.
- A link glyph if the page is going to open a reference web page.

## [0.39.2] - 2021-01-18

### Fixed

- Navigation on the iPhone. The keyboard support on the iPad broke the iPhone :-(

## [0.39.1] - 2021-01-16 Happy Birthday, Molly!

### Added

- A simple input accessory view for the phone

## [0.39.0]

### Added

- Support for iPad multitasking / multiple windows. State restoration covers the open document, selected hashtag, and opened page. Maybe someday I'll add more UI state.
- Add hashtag typeahead completion
- Cmd-N to create a new note
- Keyboard support & state restoration for the hashtags
- Cmd-Enter to enter/exit "edit mode" for the current note
- Tab & shift tab to change focus between primary and supplementary views

## [0.38.0] - 2021-01-05

### Added

- Welcome content for new notebooks.
- A setting to control whether new prompts are immediately scheduled. Defaults to TRUE so the behavior of the program is clearer for people who are just trying it out.

### Fixed

- Set the background color for the list view -- without this, it was black if there was nothing in the list.

## [0.37.0] - 2021-01-03

### Changed

- Added "creationDate" to the note schema

## [0.36.0] - 2021-01-02 Hello Hierarchy!

### Added

- Support for hierarchical hashtags! Hello, #books/2021

### Fixed

- Bug where things would get in an infinite loop if the buffer failed to parse.

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
