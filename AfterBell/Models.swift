import Foundation
import SwiftUI

struct Subject: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var code: String
    var order: Int
    var fill: String

    enum CodingKeys: String, CodingKey {
        case id, name, code, order, fill
    }

    init(id: String, name: String, code: String, order: Int, fill: String = "") {
        self.id = id
        self.name = name
        self.code = code
        self.order = order
        self.fill = fill
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        code = try c.decode(String.self, forKey: .code)
        order = try c.decode(Int.self, forKey: .order)
        fill = try c.decodeIfPresent(String.self, forKey: .fill) ?? ""
    }
}

struct Assignment: Identifiable, Codable, Hashable {
    var id: String
    var subjectId: String
    var title: String
    var notes: String
    var dueOn: String
    var priority: Priority
    var completedAt: String?

    enum Priority: String, Codable, CaseIterable, Identifiable {
        case normal
        case high
        var id: String { rawValue }
        var label: String { self == .high ? "Urgent" : "Normal" }
    }

    var isDone: Bool { completedAt != nil }
}

enum HomeworkForm: Equatable {
    case closed
    case add
    case edit(Assignment)
}

enum AppSheet: Identifiable {
    case subjects
    var id: String { "subjects" }
}

func newId(_ prefix: String) -> String {
    "\(prefix)-\(UUID().uuidString.prefix(8).lowercased())"
}

func todayISO(_ date: Date = Date()) -> String {
    isoDay.string(from: date)
}

func addDays(_ iso: String, _ days: Int) -> String {
    guard let date = isoDay.date(from: iso) else { return iso }
    return isoDay.string(from: Calendar.current.date(byAdding: .day, value: days, to: date) ?? date)
}

func startOfWeek(_ iso: String) -> String {
    guard let date = isoDay.date(from: iso) else { return iso }
    let weekday = Calendar.current.component(.weekday, from: date)
    let mondayOffset = (weekday + 5) % 7
    return isoDay.string(from: Calendar.current.date(byAdding: .day, value: -mondayOffset, to: date) ?? date)
}

func weekDays(from iso: String) -> [String] {
    let start = startOfWeek(iso)
    return (0..<7).map { addDays(start, $0) }
}

func diffDays(_ iso: String, from today: String) -> Int {
    guard let a = isoDay.date(from: iso), let b = isoDay.date(from: today) else { return 0 }
    return Calendar.current.dateComponents([.day], from: b, to: a).day ?? 0
}

func weekdayLetter(_ iso: String) -> String {
    guard let date = isoDay.date(from: iso) else { return "" }
    let i = Calendar.current.component(.weekday, from: date)
    return ["S", "M", "T", "W", "T", "F", "S"][i - 1]
}

func greeting(for hour: Int) -> String {
    switch hour {
    case 5..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    default: return "Good evening"
    }
}

func formatDue(_ iso: String, today: String) -> String {
    let delta = diffDays(iso, from: today)
    if delta == 0 { return "Today" }
    if delta == 1 { return "Tomorrow" }
    if delta == -1 { return "Yesterday" }
    if delta < 0 { return "Overdue" }
    guard let date = isoDay.date(from: iso) else { return iso }
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    return f.string(from: date)
}

func codeFromName(_ name: String, taken: [String]) -> String {
    let letters = name.uppercased().filter(\.isLetter)
    var base = String(letters.prefix(2))
    if base.count < 2 {
        base = String((base + "X").prefix(2))
    }
    var code = base
    var n = 2
    while taken.contains(code) {
        code = String((base.prefix(1) + String(n)).prefix(2))
        n += 1
    }
    return code
}

private let isoDay: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f
}()
