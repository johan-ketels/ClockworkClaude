import SwiftUI

struct ScheduleEditor: View {
    @Binding var scheduleType: ScheduleType
    @Binding var intervalValue: Int
    @Binding var intervalUnit: IntervalUnit
    @Binding var intervalAlignment: IntervalAlignment
    @Binding var calendarWeekday: Int
    @Binding var calendarHour: Int
    @Binding var calendarMinute: Int

    private let weekdays = [
        (-1, "Every day"),
        (0, "Sunday"), (1, "Monday"), (2, "Tuesday"),
        (3, "Wednesday"), (4, "Thursday"), (5, "Friday"), (6, "Saturday")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            // Section header
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(Theme.sonnet)
                Text("Schedule")
                    .font(Theme.monoBody.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            // Type picker
            HStack(spacing: 4) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Button(action: { scheduleType = type }) {
                        Text(type.displayName)
                            .font(Theme.monoSmall)
                            .foregroundStyle(scheduleType == type ? .white : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                    .fill(scheduleType == type ? Theme.sonnet : Theme.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Type-specific fields
            switch scheduleType {
            case .interval:
                intervalFields
            case .calendar:
                calendarFields
            case .once:
                Text("Job will run immediately when loaded.")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }

    private var intervalFields: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                Text("Every")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textSecondary)
                TextField("", value: $intervalValue, format: .number)
                    .font(Theme.monoBody)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .frame(width: 60)
                Picker("", selection: $intervalUnit) {
                    ForEach(IntervalUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            if intervalUnit == .hours {
                HStack(spacing: 12) {
                    ForEach(IntervalAlignment.allCases, id: \.self) { alignment in
                        HStack(spacing: 4) {
                            Image(systemName: intervalAlignment == alignment ? "circle.inset.filled" : "circle")
                                .font(.caption)
                                .foregroundStyle(intervalAlignment == alignment ? Theme.sonnet : Theme.textMuted)
                            Text(alignment.displayName)
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { intervalAlignment = alignment }
                    }
                }
            }
        }
    }

    private var calendarFields: some View {
        VStack(alignment: .leading, spacing: Theme.paddingSmall) {
            HStack {
                Text("Day:")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textSecondary)
                Picker("", selection: $calendarWeekday) {
                    ForEach(weekdays, id: \.0) { (value, name) in
                        Text(name).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            HStack {
                Text("Time:")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textSecondary)
                Picker("", selection: $calendarHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .labelsHidden()
                .frame(width: 70)
                Text(":")
                    .foregroundStyle(Theme.textMuted)
                Picker("", selection: $calendarMinute) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 70)
            }
        }
    }
}
