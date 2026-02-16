// Copyright (c) 2018-2025  Brian Dewey. Covered by the Apache 2.0 license.

import BookKit
import SwiftUI

private struct ReadingHistoryEntryDraft: Identifiable {
    let id: UUID
    var startDate: Date
    var finishDate: Date?

    var isFinished: Bool {
        get {
            finishDate != nil
        }
        set {
            if newValue {
                if finishDate == nil {
                    finishDate = startDate
                }
            } else {
                finishDate = nil
            }
        }
    }

    init(id: UUID = UUID(), startDate: Date = Date(), finishDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.finishDate = finishDate
    }

    init(entry: ReadingHistory.Entry) {
        let start = Self.date(from: entry.start)
        let finish = Self.date(from: entry.finish)
        self.id = UUID()
        self.startDate = start ?? finish ?? Date()
        self.finishDate = finish
    }

    private static func date(from components: DateComponents?) -> Date? {
        guard let components else { return nil }
        return Calendar.current.date(from: components)
    }
}

struct ReadingHistoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ReadingHistoryEntryDraft]
    @State private var pendingDeleteID: UUID?
    private let onSave: (ReadingHistory?) -> Void
    private let onDismiss: (() -> Void)?

    init(
        history: ReadingHistory?,
        onSave: @escaping (ReadingHistory?) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        let entries = history?.entries ?? []
        _drafts = State(initialValue: entries.map { ReadingHistoryEntryDraft(entry: $0) })
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        List {
            if drafts.isEmpty {
                Section {
                    Text("No reading history yet.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
            }
            ForEach(drafts) { draft in
                let draftBinding = binding(for: draft.id)
                Section(
                    header: Text(sessionHeader(for: draft)),
                    footer: deleteFooter(id: draft.id)
                ) {
                    DatePicker("Start", selection: draftBinding.startDate, displayedComponents: [.date])
                    Toggle("Finished", isOn: draftBinding.isFinished)
                    if draft.finishDate != nil {
                        DatePicker("Finish", selection: finishDateBinding(for: draftBinding), displayedComponents: [.date])
                    }
                }
                .listRowBackground(Color(uiColor: .grailSecondaryGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
        .grailListBackground()
        .background(Color(uiColor: .grailGroupedBackground))
        .alert("Delete reading session?", isPresented: isDeleteAlertPresented) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismissView()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(buildHistory())
                    dismissView()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addEntry()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addEntry() {
        drafts.insert(ReadingHistoryEntryDraft(), at: 0)
    }

    private func dismissView() {
        onDismiss?()
        dismiss()
    }

    private func deleteEntries(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    private func deleteFooter(id: UUID) -> some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                pendingDeleteID = id
            } label: {
                Label("Delete Session", systemImage: "trash")
            }
        }
    }

    private var isDeleteAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteID != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteID = nil
                }
            }
        )
    }

    private func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        pendingDeleteID = nil
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        deleteEntries(at: IndexSet(integer: index))
    }

    private func sessionHeader(for draft: ReadingHistoryEntryDraft) -> String {
        let startText = draft.startDate.formatted(date: .abbreviated, time: .omitted)
        if let finishDate = draft.finishDate {
            let finishText = finishDate.formatted(date: .abbreviated, time: .omitted)
            return "Started \(startText) · Finished \(finishText)"
        } else {
            return "Started \(startText) · In progress"
        }
    }

    private func binding(for id: UUID) -> Binding<ReadingHistoryEntryDraft> {
        Binding(
            get: {
                drafts.first(where: { $0.id == id }) ?? ReadingHistoryEntryDraft(id: id)
            },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[index] = newValue
            }
        )
    }

    private func finishDateBinding(for draft: Binding<ReadingHistoryEntryDraft>) -> Binding<Date> {
        Binding(
            get: { draft.wrappedValue.finishDate ?? draft.wrappedValue.startDate },
            set: { newValue in
                draft.wrappedValue.finishDate = newValue
            }
        )
    }

    private func buildHistory() -> ReadingHistory? {
        let normalized = normalizedDrafts()
        guard !normalized.isEmpty else { return nil }
        var history = ReadingHistory()
        for draft in normalized {
            let startComponents = Calendar.current.dateComponents([.year, .month, .day], from: draft.startDate)
            history.startReading(startDate: startComponents)
            if let finishDate = draft.finishDate {
                let finishComponents = Calendar.current.dateComponents([.year, .month, .day], from: finishDate)
                history.finishReading(finishDate: finishComponents)
            }
        }
        return history
    }

    private func normalizedDrafts() -> [ReadingHistoryEntryDraft] {
        let sorted = drafts.sorted { $0.startDate < $1.startDate }
        var normalized: [ReadingHistoryEntryDraft] = []
        var hasOpenSession = false
        for var draft in sorted {
            if let finishDate = draft.finishDate, finishDate < draft.startDate {
                draft.finishDate = draft.startDate
            }
            if draft.finishDate == nil {
                if hasOpenSession {
                    draft.finishDate = draft.startDate
                } else {
                    hasOpenSession = true
                }
            }
            normalized.append(draft)
        }
        return normalized
    }
}
