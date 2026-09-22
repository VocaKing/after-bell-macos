import AppKit
import Foundation
import Observation
import SwiftUI

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
    var weekCursor: String = todayISO()
    var feedURL: String = ""
    var feedNote: String = ""
    var feedBusy: Bool = false

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

    func dayCounts() -> [String: (open: Int, done: Int)] {
        var counts: [String: (open: Int, done: Int)] = [:]
        for day in weekDays(from: weekCursor) { counts[day] = (0, 0) }
        for item in assignments {
            guard var pair = counts[item.dueOn] else { continue }
            if item.isDone {
                pair.done += 1
            } else {
                pair.open += 1
            }
            counts[item.dueOn] = pair
        }
        return counts
    }

    var visible: [Assignment] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return assignments
            .filter { item in
                if let selectedSubjectId, item.subjectId != selectedSubjectId { return false }
                if let selectedDay {
                    if item.dueOn != selectedDay { return false }
                } else if item.isDone {
                    return false
                }
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
        if dueToday > 0 { return "Today’s list is ready." }
        return "Nothing urgent on the desk."
    }

    func summary() -> String {
        if let id = selectedSubjectId, let subject = subjects.first(where: { $0.id == id }) {
            let left = visible.filter { !$0.isDone }.count
            return left == 0 ? "\(subject.name) is clear." : "\(left) still open in \(subject.name)."
        }
        if overdue > 0 { return "\(overdue) overdue · \(dueToday) due today." }
        if dueToday > 0 { return "\(dueToday) due today. You’re on it." }
        if weekOpen > 0 { return "Clear today. \(weekOpen) still left this week." }
        return "The list is clear. Enjoy the quiet."
    }

    func addSubject(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let taken = subjects.map(\.code)
        let order = (subjects.map(\.order).max() ?? -1) + 1
        subjects.append(Subject(
            id: newId("sub"),
            name: trimmed,
            code: codeFromName(trimmed, taken: taken),
            order: order,
            fill: AfterBellTheme.brickHex(order)
        ))
        save()
    }

    func shiftWeek(_ days: Int) {
        weekCursor = addDays(startOfWeek(weekCursor), days)
    }

    func jumpToThisWeek() {
        weekCursor = today
    }

    func setSubjectFill(id: String, color: Color) {
        let hex = AfterBellTheme.hex(from: color)
        subjects = subjects.map { item in
            guard item.id == id else { return item }
            var next = item
            next.fill = hex
            return next
        }
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

    func homeworkCount(for id: String) -> (open: Int, total: Int) {
        let items = assignments.filter { $0.subjectId == id }
        return (items.filter { !$0.isDone }.count, items.count)
    }

    func removeSubject(id: String) {
        assignments.removeAll { $0.subjectId == id }
        subjects.removeAll { $0.id == id }
        if selectedSubjectId == id { selectedSubjectId = nil }
        save()
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
            assignments.append(
                Assignment(
                    id: newId("hw"),
                    subjectId: subjectId,
                    title: title,
                    notes: notes,
                    dueOn: dueOn,
                    priority: priority,
                    completedAt: nil
                )
            )
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

    func connectFeed(_ raw: String) async {
        feedURL = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
        await refreshFeed()
    }

    func clearFeed() {
        feedURL = ""
        feedNote = "Disconnected."
        save()
    }

    func refreshFeed() async {
        let raw = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else {
            feedNote = "Paste a full http(s) link."
            return
        }
        feedBusy = true
        defer { feedBusy = false }
        do {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue("text/calendar, text/html, text/plain;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 {
                feedNote = "That page needs a login. Export a calendar (.ics) from it, then paste the secret feed link."
                return
            }
            guard status == 0 || (200..<400).contains(status) else {
                feedNote = "The page returned \(status)."
                return
            }
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            let events: [FeedEvent]
            if text.contains("BEGIN:VCALENDAR") || text.contains("BEGIN:VEVENT") {
                events = parseICS(text)
            } else {
                events = parseWeb(text)
            }
            let added = importEvents(events)
            if events.isEmpty {
                feedNote = "Connected, but no homework dates were found. A calendar .ics link works more reliably than a login page."
            } else {
                feedNote = added == 0
                    ? "Checked \(events.count) items. Nothing new."
                    : "Added \(added) of \(events.count) items from the page."
            }
        } catch {
            feedNote = "Could not reach that page. Check the link, or use an .ics calendar export."
        }
    }

    @discardableResult
    private func importEvents(_ events: [FeedEvent]) -> Int {
        var added = 0
        for event in events {
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, event.dueOn.count == 10 else { continue }
            let exists = assignments.contains {
                $0.title.compare(title, options: .caseInsensitive) == .orderedSame && $0.dueOn == event.dueOn
            }
            if exists { continue }
            assignments.append(
                Assignment(
                    id: newId("hw"),
                    subjectId: guessSubjectId(from: title),
                    title: title,
                    notes: event.notes,
                    dueOn: event.dueOn,
                    priority: .normal,
                    completedAt: nil
                )
            )
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    private func guessSubjectId(from title: String) -> String {
        let t = title.lowercased()
        if let match = subjects.first(where: { t.contains($0.name.lowercased()) }) {
            return match.id
        }
        if let match = subjects.first(where: {
            t.range(of: "\\b\($0.code)\\b", options: [.regularExpression, .caseInsensitive]) != nil
        }) {
            return match.id
        }
        if subjects.isEmpty {
            addSubject(name: "Imported")
        }
        return subjects.first?.id ?? ""
    }

    private func parseICS(_ text: String) -> [FeedEvent] {
        let unfolded = text
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
        var events: [FeedEvent] = []
        var current: [String: String] = [:]
        for raw in unfolded.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "BEGIN:VEVENT" {
                current = [:]
            } else if line == "END:VEVENT" {
                let title = icsUnescape(current["SUMMARY"] ?? "")
                let due = icsDay(current["DUE"] ?? current["DTSTART"] ?? "")
                if !title.isEmpty, due.count == 10 {
                    events.append(FeedEvent(title: title, dueOn: due, notes: icsUnescape(current["DESCRIPTION"] ?? "")))
                }
            } else if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).split(separator: ";").first.map { String($0).uppercased() } ?? ""
                current[key] = String(line[line.index(after: colon)...])
            }
        }
        return events
    }

    private func parseWeb(_ html: String) -> [FeedEvent] {
        var text = html
        text = text.replacingOccurrences(of: "(?s)<script[^>]*>.*?</script>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<style[^>]*>.*?</style>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</(p|div|li|tr|h1|h2|h3|td)>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&", with: "&")
        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        var events: [FeedEvent] = []
        let iso = try? NSRegularExpression(pattern: "\\b(20\\d{2})[-/.](\\d{1,2})[-/.](\\d{1,2})\\b")
        let dmy = try? NSRegularExpression(pattern: "\\b(\\d{1,2})[-/.](\\d{1,2})[-/.](20\\d{2})\\b")
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 8, line.count < 180 else { continue }
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            var due: String?
            if let iso, let match = iso.firstMatch(in: line, range: range) {
                due = String(format: "%@-%02d-%02d", ns.substring(with: match.range(at: 1)), Int(ns.substring(with: match.range(at: 2))) ?? 0, Int(ns.substring(with: match.range(at: 3))) ?? 0)
            } else if let dmy, let match = dmy.firstMatch(in: line, range: range) {
                due = String(format: "%@-%02d-%02d", ns.substring(with: match.range(at: 3)), Int(ns.substring(with: match.range(at: 2))) ?? 0, Int(ns.substring(with: match.range(at: 1))) ?? 0)
            }
            guard let due, due.count == 10 else { continue }
            var title = line
            if let r = title.range(of: #"\b20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}\b"#, options: .regularExpression) {
                title.removeSubrange(r)
            }
            if let r = title.range(of: #"\b\d{1,2}[-/.]\d{1,2}[-/.]20\d{2}\b"#, options: .regularExpression) {
                title.removeSubrange(r)
            }
            title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            guard title.count >= 4 else { continue }
            if events.contains(where: { $0.title == title && $0.dueOn == due }) { continue }
            events.append(FeedEvent(title: title, dueOn: due, notes: "Imported from page"))
        }
        return events
    }

    private func icsDay(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count >= 8 else { return "" }
        let y = digits.prefix(4)
        let m = digits.dropFirst(4).prefix(2)
        let d = digits.dropFirst(6).prefix(2)
        return "\(y)-\(m)-\(d)"
    }

    private func icsUnescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
    }

    private func save() {
        let snap = Snapshot(subjects: subjects, assignments: assignments, feedURL: feedURL.isEmpty ? nil : feedURL)
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
        subjects = snap.subjects.map { item in
            var next = item
            if next.fill.isEmpty { next.fill = AfterBellTheme.brickHex(next.order) }
            return next
        }
        assignments = snap.assignments
        feedURL = snap.feedURL ?? ""
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
        var feedURL: String?
    }

    struct FeedEvent {
        var title: String
        var dueOn: String
        var notes: String
    }

    static let defaultSubjects: [Subject] = [
        .init(id: "sub-ma", name: "Mathematics", code: "MA", order: 0, fill: AfterBellTheme.brickHex(0)),
        .init(id: "sub-en", name: "English", code: "EN", order: 1, fill: AfterBellTheme.brickHex(1)),
        .init(id: "sub-sc", name: "Sciences", code: "SC", order: 2, fill: AfterBellTheme.brickHex(2)),
        .init(id: "sub-hi", name: "History", code: "HI", order: 3, fill: AfterBellTheme.brickHex(3)),
        .init(id: "sub-la", name: "Language", code: "LA", order: 4, fill: AfterBellTheme.brickHex(4)),
        .init(id: "sub-el", name: "Elective", code: "EL", order: 5, fill: AfterBellTheme.brickHex(5)),
    ]

    static func sampleAssignments(subjects: [Subject]) -> [Assignment] {
        let t = todayISO()
        func id(_ subject: String) -> String {
            subjects.first { $0.code == subject }?.id ?? subject
        }
        return [
            .init(id: "hw-1", subjectId: id("MA"), title: "Quadratic worksheet 3", notes: "Questions 4–12, show working.", dueOn: addDays(t, -1), priority: .high, completedAt: nil),
            .init(id: "hw-2", subjectId: id("SC"), title: "Lab write-up: titration", notes: "Results table plus one error analysis paragraph.", dueOn: t, priority: .high, completedAt: nil),
            .init(id: "hw-3", subjectId: id("EN"), title: "Chapter 4 reading notes", notes: "Annotate the river scene and bring three quotes.", dueOn: t, priority: .normal, completedAt: nil),
            .init(id: "hw-4", subjectId: id("LA"), title: "Vocab quiz prep", notes: "List 18, oral round tomorrow.", dueOn: addDays(t, 1), priority: .normal, completedAt: nil),
            .init(id: "hw-5", subjectId: id("HI"), title: "Essay outline — industrial towns", notes: "Thesis plus three body claims.", dueOn: addDays(t, 3), priority: .normal, completedAt: nil),
            .init(id: "hw-6", subjectId: id("EL"), title: "Practice recording", notes: "Two minutes, no script.", dueOn: addDays(t, 4), priority: .normal, completedAt: nil),
            .init(id: "hw-7", subjectId: id("MA"), title: "Mixed review set B", notes: "Skip the challenge question.", dueOn: addDays(t, -3), priority: .normal, completedAt: addDays(t, -2)),
        ]
    }
}
