import AppKit
import Foundation
import Observation

@Observable
final class HomeworkStore {
    var subjects: [Subject] = HomeworkStore.defaultSubjects
    var assignments: [Assignment] = []
    var selectedSubjectId: String?
    var selectedDay: String?
    var form: HomeworkForm = .closed
    var sheet: AppSheet?
    var roomImage: NSImage?
    var query: String = ""

    private let roomURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AfterBell", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        roomURL = support.appendingPathComponent("room.jpg")
        load()
        if assignments.isEmpty && subjects.isEmpty == false {
            assignments = HomeworkStore.sampleAssignments(subjects: subjects)
            save()
        }
        if FileManager.default.fileExists(atPath: roomURL.path) {
            roomImage = NSImage(contentsOf: roomURL)
        }
    }

    var today: String { todayISO() }
    var sortedSubjects: [Subject] { subjects.sorted { $0.order < $1.order } }
    var openCount: Int { assignments.filter { !$0.isDone }.count }

    var weekOpen: Int {
        let start = startOfWeek(today)
        let end = addDays(start, 6)
        return assignments.filter { !$0.isDone && $0.dueOn >= start && $0.dueOn <= end }.count
    }

    var weekDone: Int {
        let start = startOfWeek(today)
        let end = addDays(start, 6)
        return assignments.filter { $0.isDone && $0.dueOn >= start && $0.dueOn <= end }.count
    }

    var overdue: Int {
        assignments.filter { !$0.isDone && diffDays($0.dueOn, from: today) < 0 }.count
    }

    var dueToday: Int {
        assignments.filter { !$0.isDone && $0.dueOn == today }.count
    }

    func openCount(for subject: Subject) -> Int {
        assignments.filter { $0.subjectId == subject.id && !$0.isDone }.count
    }

    func dayCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for day in weekDays(from: today) { counts[day] = 0 }
        for item in assignments where !item.isDone {
            if counts[item.dueOn] != nil { counts[item.dueOn, default: 0] += 1 }
        }
        return counts
    }

    var visible: [Assignment] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return assignments
            .filter { item in
                if let selectedSubjectId, item.subjectId != selectedSubjectId { return false }
                if let selectedDay, item.dueOn != selectedDay { return false }
                if q.isEmpty { return true }
                if q == "overdue" { return !item.isDone && diffDays(item.dueOn, from: today) < 0 }
                if q == "finished" || q == "done" { return item.isDone }
                if q == "due today" || q == "today" { return !item.isDone && item.dueOn == today }
                let subject = subjects.first { $0.id == item.subjectId }
                let hay = "\(item.title) \(item.notes) \(subject?.name ?? "") \(subject?.code ?? "")".lowercased()
                return hay.contains(q)
            }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                if a.dueOn != b.dueOn { return a.dueOn < b.dueOn }
                if a.priority != b.priority { return a.priority == .high }
                return a.title < b.title
            }
    }

    func headline() -> String {
        if overdue > 0 { return "A few things are waiting." }
        if dueToday > 0 { return "Today's list is ready." }
        return "Nothing urgent on the desk."
    }

    func summary() -> String {
        if let id = selectedSubjectId, let subject = subjects.first(where: { $0.id == id }) {
            let left = visible.filter { !$0.isDone }.count
            return left == 0 ? "\(subject.name) is clear." : "\(left) still open in \(subject.name)."
        }
        if overdue > 0 { return "\(overdue) overdue · \(dueToday) due today." }
        if dueToday > 0 { return "\(dueToday) due today. You're on it." }
        if weekOpen > 0 { return "Clear today. \(weekOpen) still left this week." }
        return "The list is clear. Enjoy the quiet."
    }

    func addSubject(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let taken = subjects.map(\.code)
        let order = (subjects.map(\.order).max() ?? -1) + 1
        subjects.append(Subject(id: newId("sub"), name: trimmed, code: codeFromName(trimmed, taken: taken), order: order))
        save()
    }

    func renameSubject(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let taken = subjects.filter { $0.id != id }.map(\.code)
        subjects = subjects.map { item in
            guard item.id == id else { return item }
            var next = item
            next.name = trimmed
            next.code = codeFromName(trimmed, taken: taken)
            return next
        }
        save()
    }

    func removeSubject(id: String) -> Bool {
        if assignments.contains(where: { $0.subjectId == id }) { return false }
        subjects.removeAll { $0.id == id }
        if selectedSubjectId == id { selectedSubjectId = nil }
        save()
        return true
    }

    func saveAssignment(title: String, notes: String, subjectId: String, dueOn: String, priority: Assignment.Priority, editing: Assignment?) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if var editing {
            editing.title = title
            editing.notes = notes
            editing.subjectId = subjectId
            editing.dueOn = dueOn
            editing.priority = priority
            assignments = assignments.map { $0.id == editing.id ? editing : $0 }
        } else {
            assignments.append(Assignment(id: newId("hw"), subjectId: subjectId, title: title, notes: notes, dueOn: dueOn, priority: priority, completedAt: nil))
        }
        form = .closed
        save()
    }

    func toggle(_ id: String) {
        assignments = assignments.map { item in
            guard item.id == id else { return item }
            var next = item
            next.completedAt = item.isDone ? nil : todayISO()
            return next
        }
        save()
    }

    func removeAssignment(_ id: String) {
        assignments.removeAll { $0.id == id }
        save()
    }

    func loadSample() {
        subjects = HomeworkStore.defaultSubjects
        assignments = HomeworkStore.sampleAssignments(subjects: subjects)
        save()
    }

    func chooseRoomPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a photo for the After Bell room."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url) else { return }
        roomImage = image
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) {
            try? jpeg.write(to: roomURL)
        }
    }

    func resetRoom() {
        roomImage = nil
        try? FileManager.default.removeItem(at: roomURL)
    }

    private func save() {
        let snap = Snapshot(subjects: subjects, assignments: assignments)
        let url = dataURL()
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: url, options: .atomic)
        } catch {
            print("After Bell save failed: \(error)")
        }
    }

    private func load() {
        let url = dataURL()
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        subjects = snap.subjects
        assignments = snap.assignments
    }

    private func dataURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AfterBell", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("homework.json")
    }

    struct Snapshot: Codable {
        var subjects: [Subject]
        var assignments: [Assignment]
    }

    static let defaultSubjects: [Subject] = [
        .init(id: "sub-ma", name: "Mathematics", code: "MA", order: 0),
        .init(id: "sub-en", name: "English", code: "EN", order: 1),
        .init(id: "sub-sc", name: "Sciences", code: "SC", order: 2),
        .init(id: "sub-hi", name: "History", code: "HI", order: 3),
        .init(id: "sub-la", name: "Language", code: "LA", order: 4),
        .init(id: "sub-el", name: "Elective", code: "EL", order: 5),
    ]

    static func sampleAssignments(subjects: [Subject]) -> [Assignment] {
        let t = todayISO()
        func id(_ subject: String) -> String {
            subjects.first { $0.code == subject }?.id ?? subject
        }
        return [
            .init(id: "hw-1", subjectId: id("MA"), title: "Quadratic worksheet 3", notes: "Questions 4-12, show working.", dueOn: addDays(t, -1), priority: .high, completedAt: nil),
            .init(id: "hw-2", subjectId: id("SC"), title: "Lab write-up: titration", notes: "Results table plus one error analysis paragraph.", dueOn: t, priority: .high, completedAt: nil),
            .init(id: "hw-3", subjectId: id("EN"), title: "Chapter 4 reading notes", notes: "Annotate the river scene and bring three quotes.", dueOn: t, priority: .normal, completedAt: nil),
            .init(id: "hw-4", subjectId: id("LA"), title: "Vocab quiz prep", notes: "List 18, oral round tomorrow.", dueOn: addDays(t, 1), priority: .normal, completedAt: nil),
            .init(id: "hw-5", subjectId: id("HI"), title: "Essay outline - industrial towns", notes: "Thesis plus three body claims.", dueOn: addDays(t, 3), priority: .normal, completedAt: nil),
            .init(id: "hw-6", subjectId: id("EL"), title: "Practice recording", notes: "Two minutes, no script.", dueOn: addDays(t, 4), priority: .normal, completedAt: nil),
            .init(id: "hw-7", subjectId: id("MA"), title: "Mixed review set B", notes: "Skip the challenge question.", dueOn: addDays(t, -3), priority: .normal, completedAt: addDays(t, -2)),
        ]
    }
}
