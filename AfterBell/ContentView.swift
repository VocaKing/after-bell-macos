import SwiftUI

struct ContentView: View {
    @Environment(HomeworkStore.self) private var store
    @State private var hoveredBrick: String?

    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: 268)
            Divider().overlay(Color.white.opacity(0.08))
            MainDesk(hoveredBrick: $hoveredBrick)
        }
        .padding(.top, 44)
        .background {
            AtmosphereBackground(image: store.roomImage)
        }
        .background(AfterBellTheme.bg)
        .preferredColorScheme(.dark)
        .sheet(item: Binding(get: { store.sheet }, set: { store.sheet = $0 })) { _ in
            SubjectsSheet().frame(width: 420, height: 520)
        }
        .sheet(isPresented: Binding(
            get: { store.form != .closed },
            set: { if !$0 { store.form = .closed } }
        )) {
            AssignmentSheet().frame(width: 440, height: 520)
        }
    }
}

struct AtmosphereBackground: View {
    var image: NSImage?
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AfterBellTheme.bg
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.28))
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.14),
                            Color(red: 0.06, green: 0.05, blue: 0.04),
                            Color(red: 0.10, green: 0.09, blue: 0.07),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [Color.white.opacity(0.10), .clear],
                        center: .init(x: 0.78, y: 0.22),
                        startRadius: 20,
                        endRadius: 520
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct Sidebar: View {
    @Environment(HomeworkStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "cube.fill")
                    .foregroundStyle(AfterBellTheme.accentFg)
                    .frame(width: 36, height: 36)
                    .background { GlassSurface(tint: AfterBellTheme.accent, radius: 10) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("After Bell").font(.system(size: 22, weight: .regular, design: .serif))
                    Text("Homework, remembered").font(.system(size: 11)).foregroundStyle(AfterBellTheme.muted)
                }
            }
            .padding(.top, 8)
            WeekRing(remaining: store.weekOpen, finished: store.weekDone)
            Spacer()
            VStack(spacing: 8) {
                SidebarMenuButton(title: "Add homework", systemImage: "plus", prominent: true) {
                    store.form = .add
                }
                SidebarMenuButton(title: "Manage subjects", systemImage: "slider.horizontal.3") {
                    store.sheet = .subjects
                }
                SidebarMenuButton(
                    title: store.roomImage == nil ? "Choose room photo" : "Change room photo",
                    systemImage: "photo"
                ) {
                    store.chooseRoomPhoto()
                }
                if store.roomImage != nil {
                    Button("Restore default room") { store.resetRoom() }
                        .buttonStyle(.plain).foregroundStyle(AfterBellTheme.muted).frame(maxWidth: .infinity)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial.opacity(0.72))
    }
}

struct WeekRing: View {
    var remaining: Int
    var finished: Int
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: remaining + finished == 0 ? 0 : CGFloat(finished) / CGFloat(max(remaining + finished, 1)))
                    .stroke(AfterBellTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(remaining)").font(.system(size: 28, weight: .medium, design: .serif))
                    Text("left this week").font(.system(size: 10)).foregroundStyle(AfterBellTheme.muted)
                }
            }
            .frame(width: 132, height: 132)
            .frame(maxWidth: .infinity)
            Text("\(finished) finished").font(.system(size: 11)).foregroundStyle(AfterBellTheme.muted).frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
    }
}

struct MainDesk: View {
    @Environment(HomeworkStore.self) private var store
    @Binding var hoveredBrick: String?
    private let hour = Calendar.current.component(.hour, from: Date())
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(greeting(for: hour)).").font(.system(size: 14)).foregroundStyle(AfterBellTheme.muted)
                    Text(store.headline()).font(.system(size: 34, weight: .regular, design: .serif))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject links").font(.system(size: 11, weight: .medium)).foregroundStyle(AfterBellTheme.muted).textCase(.uppercase)
                    Text("Hover a brick, then click to open that subject.").font(.system(size: 13)).foregroundStyle(AfterBellTheme.muted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 8) {
                        ForEach(store.sortedSubjects) { subject in
                            let open = store.openCount(for: subject)
                            Button {
                                store.selectedSubjectId = store.selectedSubjectId == subject.id ? nil : subject.id
                            } label: {
                                BrickSceneView(
                                    color: AfterBellTheme.brickNSColor(subject.order),
                                    code: subject.code,
                                    name: subject.name,
                                    count: open == 0 ? "Clear" : "\(open) open",
                                    hovered: hoveredBrick == subject.id,
                                    selected: store.selectedSubjectId == subject.id
                                )
                                .frame(height: 210)
                                .onHover { inside in
                                    hoveredBrick = inside ? subject.id : (hoveredBrick == subject.id ? nil : hoveredBrick)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                InquiryRow()
                WeekStripView()
                HStack {
                    Text(store.query.isEmpty && store.selectedSubjectId == nil && store.selectedDay == nil ? "Open work" : "Matches")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(AfterBellTheme.muted).textCase(.uppercase)
                    Spacer()
                    if let id = store.selectedSubjectId, let subject = store.subjects.first(where: { $0.id == id }) {
                        Button { store.selectedSubjectId = nil } label: {
                            HStack(spacing: 4) {
                                Text(subject.name)
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            }
                            .font(.system(size: 11)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background { GlassSurface(tint: AfterBellTheme.accent, capsule: true) }
                        }.buttonStyle(.plain)
                    }
                    Text("\(store.visible.count)").font(.system(size: 11, design: .monospaced)).foregroundStyle(AfterBellTheme.muted)
                }
                if store.visible.isEmpty {
                    VStack(spacing: 10) {
                        Text("Empty desk").font(.system(size: 28, design: .serif))
                        Text("Add the first assignment, or load a sample week from Manage subjects.")
                            .foregroundStyle(AfterBellTheme.muted).multilineTextAlignment(.center)
                        Button { store.form = .add } label: { Label("Add homework", systemImage: "plus") }
                            .buttonStyle(GlassActionStyle(prominent: true))
                            .focusEffectDisabled()
                            .frame(width: 200)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                    .background { GlassSurface(radius: 18) }
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.visible) { item in AssignmentRow(item: item) }
                    }
                }
            }
            .padding(28)
            .padding(.top, 8)
        }
    }
}

struct InquiryRow: View {
    @Environment(HomeworkStore.self) private var store
    @State private var searchHovered = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ask what is due, overdue, or already finished", text: Binding(get: { store.query }, set: { store.query = $0 }))
                .textFieldStyle(.plain).padding(.horizontal, 16).frame(height: 44)
                .background { GlassSurface(tint: Color.white.opacity(searchHovered ? 0.8 : 0.5), capsule: true) }
                .scaleEffect(searchHovered ? 1.015 : 1)
                .shadow(color: Color.white.opacity(searchHovered ? 0.22 : 0.04), radius: searchHovered ? 12 : 3, y: searchHovered ? 4 : 1)
                .onHover { inside in
                    searchHovered = inside
                    HoverCursor.set(inside)
                }
                .animation(.easeOut(duration: 0.16), value: searchHovered)
            Text(store.summary()).font(.system(size: 13)).foregroundStyle(AfterBellTheme.muted)
            HStack(spacing: 8) {
                ForEach(["Due today", "Overdue", "Finished"], id: \.self) { chip in
                    HoverChip(
                        title: chip,
                        on: store.query == chip.lowercased()
                    ) {
                        store.query = store.query == chip.lowercased() ? "" : chip.lowercased()
                    }
                }
            }
        }
    }
}

struct HoverChip: View {
    var title: String
    var on: Bool
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(title, action: action)
            .buttonStyle(GlassChipStyle(on: on, hovered: hovered))
            .onHover { inside in
                hovered = inside
                HoverCursor.set(inside)
            }
            .animation(.easeOut(duration: 0.16), value: hovered)
            .focusEffectDisabled()
    }
}

struct WeekStripView: View {
    @Environment(HomeworkStore.self) private var store
    var body: some View {
        let days = weekDays(from: store.today)
        let counts = store.dayCounts()
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                WeekDayCell(
                    day: day,
                    selected: store.selectedDay == day,
                    isToday: day == store.today,
                    hasWork: (counts[day] ?? 0) > 0
                ) {
                    store.selectedDay = store.selectedDay == day ? nil : day
                }
            }
        }
        .padding(6)
        .background { GlassSurface(radius: 18) }
    }
}

struct WeekDayCell: View {
    var day: String
    var selected: Bool
    var isToday: Bool
    var hasWork: Bool
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(weekdayLetter(day)).font(.system(size: 11, weight: .medium)).foregroundStyle(AfterBellTheme.muted)
                Text("\(Int(day.suffix(2)) ?? 0)")
                    .font(.system(size: 16, weight: isToday ? .semibold : .regular))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isToday ? AfterBellTheme.accent : (hovered ? Color.white.opacity(0.14) : .clear)))
                    .foregroundStyle(isToday ? AfterBellTheme.accentFg : AfterBellTheme.fg)
                Circle().fill(AfterBellTheme.fg.opacity(hasWork ? 0.55 : 0.12)).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(selected || hovered ? Color.white.opacity(hovered ? 0.10 : 0.06) : .clear)
            .scaleEffect(hovered ? 1.06 : 1)
            .offset(y: hovered ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hovered = inside
            HoverCursor.set(inside)
        }
        .animation(.easeOut(duration: 0.16), value: hovered)
        .focusEffectDisabled()
    }
}

struct AssignmentRow: View {
    @Environment(HomeworkStore.self) private var store
    var item: Assignment
    @State private var hovered = false
    var body: some View {
        let subject = store.subjects.first { $0.id == item.subjectId }
        HStack(spacing: 12) {
            Button { store.toggle(item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isDone ? AfterBellTheme.muted : AfterBellTheme.fg)
            }.buttonStyle(.plain)
            HomeworkGlyph(
                code: subject?.code ?? "-",
                color: AfterBellTheme.brick(subject?.order ?? 0),
                hovered: hovered
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .semibold)).strikethrough(item.isDone)
                HStack(spacing: 6) {
                    Text(subject?.name ?? "")
                    Text("·")
                    Text(formatDue(item.dueOn, today: store.today))
                        .foregroundStyle(diffDays(item.dueOn, from: store.today) < 0 && !item.isDone ? AfterBellTheme.danger : AfterBellTheme.muted)
                    if item.priority == .high && !item.isDone {
                        Text("·")
                        Text("Urgent").foregroundStyle(AfterBellTheme.warn)
                    }
                }.font(.system(size: 12)).foregroundStyle(AfterBellTheme.muted)
                if !item.notes.isEmpty {
                    Text(item.notes).font(.system(size: 13)).foregroundStyle(AfterBellTheme.fg.opacity(0.8))
                }
            }
            Spacer()
            HoverIconButton(systemImage: "pencil") { store.form = .edit(item) }
            HoverIconButton(systemImage: "trash") { store.removeAssignment(item.id) }
        }
        .padding(12)
        .background { GlassSurface(tint: Color.white.opacity(hovered ? 0.7 : 0.45), radius: 16) }
        .scaleEffect(hovered ? 1.012 : 1)
        .offset(y: hovered ? -2 : 0)
        .onHover { inside in
            hovered = inside
            HoverCursor.set(inside)
        }
        .animation(.easeOut(duration: 0.16), value: hovered)
        .opacity(item.isDone ? 0.72 : 1)
    }
}

struct HoverIconButton: View {
    var systemImage: String
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(hovered ? AfterBellTheme.fg : AfterBellTheme.muted)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background { GlassSurface(tint: Color.white.opacity(hovered ? 0.85 : 0.45), radius: 8) }
        .scaleEffect(hovered ? 1.12 : 1)
        .offset(y: hovered ? -2 : 0)
        .onHover { inside in
            hovered = inside
            HoverCursor.set(inside)
        }
        .animation(.easeOut(duration: 0.14), value: hovered)
        .focusEffectDisabled()
    }
}

enum HoverCursor {
    static func set(_ on: Bool) {
        if on { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }
}

struct SidebarMenuButton: View {
    var title: String
    var systemImage: String
    var prominent: Bool = false
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassActionStyle(prominent: prominent, hovered: hovered))
        .onHover { inside in
            hovered = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .focusEffectDisabled()
        .animation(.easeOut(duration: 0.16), value: hovered)
    }
}

struct GlassActionStyle: ButtonStyle {
    var prominent: Bool
    var hovered: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? AfterBellTheme.accentFg : AfterBellTheme.fg)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background {
                GlassSurface(
                    tint: prominent ? AfterBellTheme.accent : Color.white.opacity(hovered ? 0.75 : 0.55),
                    radius: 12
                )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : (hovered ? 1.045 : 1))
            .offset(y: hovered ? -3 : 0)
            .shadow(color: Color.white.opacity(hovered ? 0.28 : 0.06), radius: hovered ? 14 : 4, y: hovered ? 5 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct GlassChipStyle: ButtonStyle {
    var on: Bool
    var hovered: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(on ? AfterBellTheme.accentFg : AfterBellTheme.fg)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background {
                GlassSurface(
                    tint: on ? AfterBellTheme.accent : Color.white.opacity(hovered ? 0.75 : 0.4),
                    capsule: true
                )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : (hovered ? 1.06 : 1))
            .offset(y: hovered ? -3 : 0)
            .shadow(color: Color.white.opacity(hovered ? 0.24 : 0.05), radius: hovered ? 10 : 3, y: hovered ? 4 : 1)
    }
}
