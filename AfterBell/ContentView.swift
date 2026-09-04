import SwiftUI

struct ContentView: View {
    @Environment(HomeworkStore.self) private var store
    @State private var hoveredBrick: String?

    var body: some View {
        ZStack {
            AtmosphereBackground(image: store.roomImage)
            HStack(spacing: 0) {
                Sidebar().frame(width: 268)
                Divider().overlay(Color.white.opacity(0.08))
                MainDesk(hoveredBrick: $hoveredBrick)
            }
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
        ZStack {
            AfterBellTheme.bg
            if let image {
                Image(nsImage: image).resizable().scaledToFill().overlay(Color.black.opacity(0.35))
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
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct Sidebar: View {
    @Environment(HomeworkStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AfterBellTheme.accent)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "cube.fill").foregroundStyle(AfterBellTheme.accentFg))
                VStack(alignment: .leading, spacing: 2) {
                    Text("After Bell").font(.system(size: 22, weight: .regular, design: .serif))
                    Text("Homework, remembered").font(.system(size: 11)).foregroundStyle(AfterBellTheme.muted)
                }
            }
            .padding(.top, 8)
            WeekRing(remaining: store.weekOpen, finished: store.weekDone)
            Spacer()
            VStack(spacing: 8) {
                Button { store.form = .add } label: {
                    Label("Add homework", systemImage: "plus").frame(maxWidth: .infinity)
                }.buttonStyle(AccentButtonStyle())
                Button { store.sheet = .subjects } label: {
                    Label("Manage subjects", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                }.buttonStyle(GlassButtonStyle())
                Button { store.chooseRoomPhoto() } label: {
                    Label(store.roomImage == nil ? "Choose room photo" : "Change room photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(GlassButtonStyle())
                if store.roomImage != nil {
                    Button("Restore default room") { store.resetRoom() }
                        .buttonStyle(.plain)
                        .foregroundStyle(AfterBellTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial.opacity(0.55))
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
                                .frame(height: 168)
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
                            .font(.system(size: 11))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(AfterBellTheme.raised, in: Capsule())
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
                            .buttonStyle(AccentButtonStyle()).frame(width: 200)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                    .background(AfterBellTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.visible) { item in AssignmentRow(item: item) }
                    }
                }
            }
            .padding(28)
        }
    }
}

struct InquiryRow: View {
    @Environment(HomeworkStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ask what is due, overdue, or already finished", text: Binding(get: { store.query }, set: { store.query = $0 }))
                .textFieldStyle(.plain).padding(.horizontal, 16).frame(height: 44)
                .background(AfterBellTheme.surface.opacity(0.78), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.08)))
            Text(store.summary()).font(.system(size: 13)).foregroundStyle(AfterBellTheme.muted)
            HStack(spacing: 8) {
                ForEach(["Due today", "Overdue", "Finished"], id: \.self) { chip in
                    Button(chip) { store.query = store.query == chip.lowercased() ? "" : chip.lowercased() }
                        .buttonStyle(ChipButtonStyle(on: store.query == chip.lowercased()))
                }
            }
        }
    }
}

struct WeekStripView: View {
    @Environment(HomeworkStore.self) private var store
    var body: some View {
        let days = weekDays(from: store.today)
        let counts = store.dayCounts()
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let selected = store.selectedDay == day
                let isToday = day == store.today
                Button { store.selectedDay = store.selectedDay == day ? nil : day } label: {
                    VStack(spacing: 6) {
                        Text(weekdayLetter(day)).font(.system(size: 11, weight: .medium)).foregroundStyle(AfterBellTheme.muted)
                        Text("\(Int(day.suffix(2)) ?? 0)")
                            .font(.system(size: 16, weight: isToday ? .semibold : .regular))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isToday ? AfterBellTheme.accent : .clear))
                            .foregroundStyle(isToday ? AfterBellTheme.accentFg : AfterBellTheme.fg)
                        Circle().fill(AfterBellTheme.fg.opacity((counts[day] ?? 0) > 0 ? 0.55 : 0.12)).frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(selected ? Color.white.opacity(0.06) : .clear)
                }.buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(AfterBellTheme.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08)))
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
            BrickSceneView(
                color: AfterBellTheme.brickNSColor(subject?.order ?? 0),
                code: subject?.code ?? "-",
                name: subject?.name ?? "",
                count: "",
                hovered: hovered,
                selected: false,
                compact: true
            ).frame(width: 72, height: 80)
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
            Button { store.form = .edit(item) } label: {
                Image(systemName: "pencil").foregroundStyle(AfterBellTheme.muted)
            }.buttonStyle(.plain)
            Button { store.removeAssignment(item.id) } label: {
                Image(systemName: "trash").foregroundStyle(AfterBellTheme.muted)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(AfterBellTheme.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
        .onHover { hovered = $0 }
        .opacity(item.isDone ? 0.72 : 1)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).padding(.vertical, 10)
            .background(AfterBellTheme.accent.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(AfterBellTheme.accentFg)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1)))
            .foregroundStyle(AfterBellTheme.fg)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var on: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(on ? AfterBellTheme.accent : AfterBellTheme.raised, in: Capsule())
            .foregroundStyle(on ? AfterBellTheme.accentFg : AfterBellTheme.fg)
    }
}
