import SwiftUI

/// Signature is fixed.
struct SeriesEditorView: View {
    var onCancel: () -> Void
    var onCreate: ([AlarmRecord]) -> Void

    @State private var firstHour = 6
    @State private var firstMinute = 0
    @State private var lastHour = 7
    @State private var lastMinute = 0
    @State private var gapMinutes = 10
    @State private var repeatChoice: SeriesRepeat = .weekdays
    @State private var missionScope: SeriesMissionScope = .none
    @State private var mission: Mission = .defaultWake
    @State private var pickingMission = false

    private var slots: [SeriesGenerator.Slot] {
        SeriesGenerator.slots(
            firstHour: firstHour,
            firstMinute: firstMinute,
            lastHour: lastHour,
            lastMinute: lastMinute,
            gapMinutes: gapMinutes
        )
    }

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top, spacing: 12) {
                            timeCard(title: "FIRST", hour: $firstHour, minute: $firstMinute)
                            timeCard(title: "LAST", hour: $lastHour, minute: $lastMinute)
                        }
                        gapSection
                        previewSection
                        optionsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                createButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $pickingMission) {
            NavigationStack {
                MissionPickerView(mission: mission) { chosen in
                    if let chosen {
                        mission = chosen
                    } else {
                        missionScope = .none
                    }
                    pickingMission = false
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Alarm series")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.body)
                    .foregroundStyle(WakeTheme.accent)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func timeCard(title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WakeTheme.secondary)
                .tracking(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(clock(hour: hour.wrappedValue, minute: minute.wrappedValue))
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(hour.wrappedValue < 12 ? "AM" : "PM")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(WakeTheme.secondary)
            }
            HStack(spacing: 0) {
                stepButton(systemName: "minus") {
                    step(hour: hour, minute: minute, by: -1)
                }
                Divider().overlay(WakeTheme.separator).frame(height: 18)
                stepButton(systemName: "plus") {
                    step(hour: hour, minute: minute, by: 1)
                }
            }
            .frame(height: 36)
            .background(WakeTheme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WakeTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var gapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GAP BETWEEN ALARMS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WakeTheme.secondary)
                    .tracking(0.6)
                Spacer()
                Text("\(gapMinutes) min")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            Slider(
                value: Binding(
                    get: { Double(gapMinutes) },
                    set: { gapMinutes = Int($0.rounded()) }
                ),
                in: 5...30,
                step: 5
            )
            .tint(WakeTheme.accent)
            HStack {
                ForEach([5, 10, 15, 20, 25, 30], id: \.self) { minute in
                    Text("\(minute)")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption2)
            .foregroundStyle(WakeTheme.tertiary)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PREVIEW")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WakeTheme.secondary)
                    .tracking(0.6)
                Spacer()
                Text("\(slots.count) ALARMS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WakeTheme.secondary)
                    .tracking(0.6)
            }
            ChipFlow(spacing: 8) {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let marked = missionScope == .every || (missionScope == .last && index == slots.count - 1)
                    Text(slot.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(marked ? Color.black : Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            marked ? Color.white : WakeTheme.elevated,
                            in: Capsule()
                        )
                }
            }
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Repeat")
                    .foregroundStyle(.white)
                Spacer()
                Menu {
                    ForEach(SeriesRepeat.allCases) { choice in
                        Button(choice.title) { repeatChoice = choice }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(repeatChoice.title)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(WakeTheme.secondary)
                }
            }
            Divider().overlay(WakeTheme.separator)
            missionCard
        }
        .padding(16)
        .background(WakeTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Wake-up mission on")
                .foregroundStyle(.white)
            HStack(spacing: 0) {
                missionSegment("None", selected: missionScope == .none) {
                    missionScope = .none
                }
                missionSegment("Last alarm only", selected: missionScope == .last) {
                    chooseMissionScope(.last)
                }
                missionSegment("Every alarm", selected: missionScope == .every) {
                    chooseMissionScope(.every)
                }
            }
            .padding(3)
            .background(WakeTheme.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if missionScope != .none {
                Button {
                    pickingMission = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mission.symbolName)
                            .font(.title3)
                            .foregroundStyle(WakeTheme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mission.editorTitle)
                                .foregroundStyle(.white)
                            Text(mission.editorDetail)
                                .font(.subheadline)
                                .foregroundStyle(WakeTheme.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WakeTheme.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wake-up mission, \(mission.editorTitle)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func missionSegment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Color.black : WakeTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(
                    selected ? Color.white : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private var createButton: some View {
        Button(action: create) {
            Text(SeriesGenerator.createButtonTitle(count: slots.count))
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func create() {
        let seriesID = UUID()
        let days = repeatChoice.days
        let records = slots.enumerated().map { index, slot in
            let isLast = index == slots.count - 1
            return AlarmRecord(
                id: UUID(),
                hour: slot.hour,
                minute: slot.minute,
                repeatDays: days,
                oneShotDate: nil,
                label: "Alarm",
                sound: AlarmSound.radial.rawValue,
                snoozeEnabled: true,
                mission: seriesMission(isLast: isLast),
                seriesID: seriesID,
                isEnabled: true
            )
        }
        onCreate(records)
    }

    private func chooseMissionScope(_ scope: SeriesMissionScope) {
        missionScope = scope
    }

    private func seriesMission(isLast: Bool) -> Mission? {
        switch missionScope {
        case .none:
            nil
        case .last:
            isLast ? mission : nil
        case .every:
            mission
        }
    }

    private func step(hour: Binding<Int>, minute: Binding<Int>, by delta: Int) {
        let total = ((hour.wrappedValue * 60 + minute.wrappedValue + delta) % (24 * 60) + (24 * 60)) % (24 * 60)
        hour.wrappedValue = total / 60
        minute.wrappedValue = total % 60
    }

    private func clock(hour: Int, minute: Int) -> String {
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):\(String(format: "%02d", minute))"
    }
}

private enum SeriesMissionScope {
    case none, last, every
}

private enum SeriesRepeat: String, CaseIterable, Identifiable {
    case never
    case everyDay
    case weekdays
    case weekends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .everyDay: "Every day"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        }
    }

    var days: [Weekday] {
        switch self {
        case .never: []
        case .everyDay: Array(Weekday.allCases)
        case .weekdays: Weekday.weekdays
        case .weekends: Weekday.weekend
        }
    }
}

private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rows(width: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxHeight } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.maxHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var used: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : used + spacing + size.width
            if !current.indices.isEmpty, needed > width {
                rows.append(current)
                current = Row()
                used = 0
            }
            current.indices.append(index)
            current.maxHeight = max(current.maxHeight, size.height)
            used = current.indices.count == 1 ? size.width : used + spacing + size.width
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }

    private struct Row {
        var indices: [Int] = []
        var maxHeight: CGFloat = 0
    }
}
