import SwiftUI

struct AssignmentSheet: View {
    @Environment(HomeworkStore.self) private var store
    @State private var title = ""
    @State private var notes = ""
    @State private var subjectId = ""
    @State private var due = Date()
    @State private var urgent = false

    var editing: Assignment? {
        if case .edit(let item) = store.form { return item }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editing == nil ? "Add homework" : "Edit homework")
                .font(.system(size: 24, design: .serif))
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            Picker("Subject", selection: $subjectId) {
                ForEach(store.sortedSubjects) { subject in
                    Text("\(subject.code)  \(subject.name)").tag(subject.id)
                }
            }
            DatePicker("Due", selection: $due, displayedComponents: .date)
            Toggle("Urgent", isOn: $urgent)
            Spacer()
            HStack {
                Button("Cancel") { store.form = .closed }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(editing == nil ? "Add" : "Save") {
                    store.saveAssignment(
                        title: title,
                        notes: notes,
                        subjectId: subjectId,
                        dueOn: todayISO(due),
                        priority: urgent ? .high : .normal,
                        editing: editing
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || subjectId.isEmpty)
            }
        }
        .padding(24)
        .onAppear {
            if let editing {
                title = editing.title
                notes = editing.notes
                subjectId = editing.subjectId
                urgent = editing.priority == .high
                due = isoDate(editing.dueOn) ?? Date()
            } else {
                subjectId = store.selectedSubjectId ?? store.sortedSubjects.first?.id ?? ""
                due = Date()
            }
        }
    }
}

struct SubjectsSheet: View {
    @Environment(HomeworkStore.self) private var store
    @State private var newName = ""
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage subjects")
                .font(.system(size: 24, design: .serif))
            HStack {
                TextField("New subject", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
            }
            if !error.isEmpty {
                Text(error).foregroundStyle(AfterBellTheme.danger).font(.system(size: 12))
            }
            List {
                ForEach(store.sortedSubjects) { subject in
                    HStack(spacing: 10) {
                        ColorPicker(
                            "Fill",
                            selection: Binding(
                                get: { AfterBellTheme.brick(subject) },
                                set: { store.setSubjectFill(id: subject.id, color: $0) }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 36)
                        TextField("Name", text: Binding(
                            get: { subject.name },
                            set: { store.renameSubject(id: subject.id, name: $0) }
                        ))
                        .textFieldStyle(.plain)
                        Text(subject.code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AfterBellTheme.muted)
                        Button {
                            if !store.removeSubject(id: subject.id) {
                                error = "Finish or move homework in \(subject.name) first."
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
            Text("Click the colour well to fill that block with any colour.")
                .font(.system(size: 12))
                .foregroundStyle(AfterBellTheme.muted)
            HStack {
                Button("Load sample week") { store.loadSample() }
                Spacer()
                Button("Done") { store.sheet = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    func add() {
        store.addSubject(name: newName)
        newName = ""
    }
}

private func isoDate(_ iso: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: iso)
}
