# Agent Notes

- Use `CONTRIBUTING.md` as the primary project orientation guide.
- SwiftFormat is the expected mechanical style tool for Swift changes when formatting is needed.
- Do not run SwiftLint as a required contribution check. The repository has a `.swiftlint.yml`, but the codebase is not currently SwiftLint-clean.
- For app changes, ensure the shared `Dogeared Notes` scheme builds for both generic iOS and Mac Catalyst before handoff unless a local environment issue blocks validation.
- Keep documentation changes focused on setup, repository structure, workflows, formats, architectural boundaries, and rationale. Avoid duplicating behavior that is obvious from nearby code or tests.
