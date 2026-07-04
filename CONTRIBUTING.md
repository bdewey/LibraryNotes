# Contributing

This repository contains Dogeared Notes, the iOS and Mac app, plus shared domain logic and a small command-line tool for working with Dogeared databases.

## Requirements

- Xcode 26.5.
- SwiftFormat and SwiftLint for local style checks.
- The app currently targets iOS 18 and Mac Catalyst. The shared Swift package targets iOS 18 and macOS 14.

## Repository Map

- `LibraryNotes/`: UIKit app code, document coordination, app-specific views, and platform integration.
- `LibraryNotesCore/`: Swift package for portable domain logic, note storage, prompt extraction, scheduling, and Markdown import/export.
- `dogeared/`: Swift command-line tool for inspecting, exporting, and importing `.libnotes` databases.
- `LibraryNotesTests/`: app target tests.
- `LibraryNotesCore/Tests/`: package tests for portable core behavior.
- `Docs/`: durable design notes and external-facing formats.
- `Content/`: starter library content used by the app.

## Building

Open `LibraryNotes.xcodeproj` in Xcode and use the shared `Dogeared Notes` scheme for app development.

Useful command-line checks:

```sh
xcodebuild -scheme "Dogeared Notes" -project LibraryNotes.xcodeproj build
swift test --package-path LibraryNotesCore
swift build --package-path dogeared
```

The Xcode project also contains a shared `uitesting` scheme for UI-oriented checks.

## Formatting And Linting

Swift formatting is defined in `.swiftformat`; SwiftLint rules are defined in `.swiftlint.yml`.

Before opening a pull request or handing off a larger change, run the formatter and linter if they are installed:

```sh
swiftformat .
swiftlint
```

The style rules intentionally cover mechanical conventions such as indentation, imports, headers, and selected lint checks. Prefer following local code structure for higher-level design conventions.

## Where Changes Belong

- Put portable model, storage, import/export, prompt extraction, scheduling, and parsing behavior in `LibraryNotesCore`.
- Put UIKit, document browser, file coordination, app lifecycle, and platform-specific UI behavior in `LibraryNotes`.
- Put command-line database workflows in `dogeared`, backed by reusable logic in `LibraryNotesCore` when possible.
- Add tests near the behavior being changed. Core behavior usually belongs in `LibraryNotesCore/Tests`; app integration behavior usually belongs in `LibraryNotesTests`.

## Command-Line Tool

The `dogeared` package provides command-line workflows for `.libnotes` databases:

```sh
swift run --package-path dogeared dogeared stats path/to/library.libnotes
swift run --package-path dogeared dogeared export path/to/library.libnotes --output exported-notes
swift run --package-path dogeared dogeared import path/to/library.libnotes exported-notes
```

Use `--help` on the command or any subcommand for the full option list.

## Documentation Guidelines

Keep documentation focused on things that are hard to infer safely from code: setup, repository structure, data formats, architectural boundaries, operational workflows, and design rationale.

Avoid duplicating implementation details that are obvious from local code. If a behavior is best understood by reading a type or test, prefer linking or naming that file instead of rewriting the same logic in prose.
