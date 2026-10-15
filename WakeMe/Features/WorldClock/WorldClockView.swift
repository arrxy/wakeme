import SwiftUI

private struct WorldCity: Identifiable, Hashable {
    let name: String
    let timeZoneID: String
    var id: String { timeZoneID }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

private enum WorldClockStore {
    static let key = "wakeme.worldclock.cities"
    static let defaults = ["America/New_York", "Europe/London", "Asia/Tokyo"]

    static let catalog: [WorldCity] = [
        WorldCity(name: "New York", timeZoneID: "America/New_York"),
        WorldCity(name: "Los Angeles", timeZoneID: "America/Los_Angeles"),
        WorldCity(name: "Chicago", timeZoneID: "America/Chicago"),
        WorldCity(name: "Denver", timeZoneID: "America/Denver"),
        WorldCity(name: "Mexico City", timeZoneID: "America/Mexico_City"),
        WorldCity(name: "São Paulo", timeZoneID: "America/Sao_Paulo"),
        WorldCity(name: "London", timeZoneID: "Europe/London"),
        WorldCity(name: "Paris", timeZoneID: "Europe/Paris"),
        WorldCity(name: "Berlin", timeZoneID: "Europe/Berlin"),
        WorldCity(name: "Rome", timeZoneID: "Europe/Rome"),
        WorldCity(name: "Moscow", timeZoneID: "Europe/Moscow"),
        WorldCity(name: "Dubai", timeZoneID: "Asia/Dubai"),
        WorldCity(name: "Mumbai", timeZoneID: "Asia/Kolkata"),
        WorldCity(name: "Singapore", timeZoneID: "Asia/Singapore"),
        WorldCity(name: "Hong Kong", timeZoneID: "Asia/Hong_Kong"),
        WorldCity(name: "Beijing", timeZoneID: "Asia/Shanghai"),
        WorldCity(name: "Seoul", timeZoneID: "Asia/Seoul"),
        WorldCity(name: "Tokyo", timeZoneID: "Asia/Tokyo"),
        WorldCity(name: "Sydney", timeZoneID: "Australia/Sydney"),
        WorldCity(name: "Auckland", timeZoneID: "Pacific/Auckland"),
    ]

    static func city(for id: String) -> WorldCity? {
        catalog.first { $0.timeZoneID == id }
    }

    static func load() -> [String] {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaults }
        return UserDefaults.standard.stringArray(forKey: key) ?? defaults
    }

    static func save(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: key)
    }
}

struct WorldClockView: View {
    @State private var selectedIDs: [String] = WorldClockStore.load()
    @State private var isEditing = false
    @State private var showAdd = false

    var body: some View {
        ZStack {
            WakeTheme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                header
                Text("World Clock")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                clockList
            }
        }
        .sheet(isPresented: $showAdd) {
            WorldClockAddSheet(selectedIDs: $selectedIDs)
        }
        .onChange(of: selectedIDs) { _, ids in
            WorldClockStore.save(ids)
        }
    }

    private var header: some View {
        HStack {
            Button(isEditing ? "Done" : "Edit") {
                isEditing.toggle()
            }
            .font(.system(size: 17))
            .foregroundStyle(WakeTheme.accent)
            Spacer()
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WakeTheme.accent)
            }
            .accessibilityLabel("Add city")
            .opacity(isEditing ? 0 : 1)
            .disabled(isEditing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var clockList: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                LazyVStack(spacing: 0) {
                    let cities = selectedIDs.compactMap(WorldClockStore.city(for:))
                    if cities.isEmpty {
                        Text("No cities")
                            .font(.system(size: 17))
                            .foregroundStyle(WakeTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    ForEach(cities) { city in
                        WorldClockRow(
                            city: city,
                            now: context.date,
                            isEditing: isEditing,
                            onDelete: { delete(city.timeZoneID) }
                        )
                        Divider().overlay(WakeTheme.separator)
                    }
                }
            }
        }
    }

    private func delete(_ id: String) {
        selectedIDs.removeAll { $0 == id }
    }
}

private struct WorldClockRow: View {
    let city: WorldCity
    let now: Date
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(WakeTheme.destructive)
                }
                .accessibilityLabel("Delete \(city.name)")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(offsetText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WakeTheme.secondary)
                    .textCase(.uppercase)
                Text(city.name)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 8)
            timeView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(city.name), \(spokenTime)")
    }

    private var timeView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(timeParts.clock)
                .font(.system(size: 48, weight: .thin, design: .default))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(timeParts.period)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private var timeParts: (clock: String, period: String) {
        let formatter = DateFormatter()
        formatter.timeZone = city.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm"
        let clock = formatter.string(from: now)
        formatter.dateFormat = "a"
        return (clock, formatter.string(from: now))
    }

    private var spokenTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = city.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: now)
    }

    private var offsetText: String {
        let zone = city.timeZone
        let local = TimeZone.current
        let delta = zone.secondsFromGMT(for: now) - local.secondsFromGMT(for: now)
        let day = dayWord(zone: zone)
        let hours = offsetHours(delta)
        return "\(day), \(hours)"
    }

    private func dayWord(zone: TimeZone) -> String {
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = .current
        var cityCal = Calendar(identifier: .gregorian)
        cityCal.timeZone = zone
        let localDay = localCal.dateComponents([.year, .month, .day], from: now)
        let cityDay = cityCal.dateComponents([.year, .month, .day], from: now)
        guard
            let localDate = localCal.date(from: localDay),
            let cityDate = localCal.date(from: cityDay)
        else { return "Today" }
        let diff = localCal.dateComponents([.day], from: localDate, to: cityDate).day ?? 0
        if diff < 0 { return "Yesterday" }
        if diff > 0 { return "Tomorrow" }
        return "Today"
    }

    private func offsetHours(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let absSeconds = abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        if minutes == 0 {
            return "\(sign)\(hours)HRS"
        }
        return String(format: "%@%d:%02d", sign, hours, minutes)
    }
}

private struct WorldClockAddSheet: View {
    @Binding var selectedIDs: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [WorldCity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let available = WorldClockStore.catalog.filter { !selectedIDs.contains($0.timeZoneID) }
        guard !q.isEmpty else { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WakeTheme.background.ignoresSafeArea()
                List(results) { city in
                    Button {
                        if !selectedIDs.contains(city.timeZoneID) {
                            selectedIDs.append(city.timeZoneID)
                        }
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name)
                                .foregroundStyle(.white)
                            Text(city.timeZoneID)
                                .font(.caption)
                                .foregroundStyle(WakeTheme.secondary)
                        }
                    }
                    .listRowBackground(WakeTheme.card)
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $query, prompt: "Search")
            }
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(WakeTheme.accent)
                }
            }
            .toolbarBackground(WakeTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
