import SwiftUI

// MARK: - Reminder Duration Picker

public struct ReminderDurationPicker: View {
    @Binding var duration: TimeInterval
    
    private let presets: [(String, TimeInterval)] = [
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("1 hr", 60 * 60),
        ("2 hr", 2 * 60 * 60),
        ("4 hr", 4 * 60 * 60),
        ("8 hr", 8 * 60 * 60),
        ("24 hr", 24 * 60 * 60),
    ]
    
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    
    private let minuteOptions = Array(0...59)
    
    public init(duration: Binding<TimeInterval>) {
        self._duration = duration
        let total = Int(duration.wrappedValue)
        self._hours = State(initialValue: total / 3600)
        self._minutes = State(initialValue: (total % 3600) / 60)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminder Duration")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            // Quick preset buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.1) { label, value in
                        Button(action: {
                            duration = value
                            hours = Int(value) / 3600
                            minutes = (Int(value) % 3600) / 60
                        }) {
                            Text(label)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    duration == value
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear
                                )
                                .modifier(LiquidGlassModifier(style: .badge))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            duration == value
                                                ? Color.accentColor.opacity(0.5)
                                                : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Custom time pickers
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Picker("", selection: $hours) {
                        ForEach(0...24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 60)
                    Text("hr")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Picker("", selection: $minutes) {
                        ForEach(minuteOptions, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 60)
                    Text("min")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: hours) { _, _ in updateDuration() }
            .onChange(of: minutes) { _, _ in updateDuration() }
        }
    }
    
    private func updateDuration() {
        var totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
        // Cap at 24 hours
        let maxDuration: TimeInterval = 24 * 60 * 60
        if totalSeconds > maxDuration {
            totalSeconds = maxDuration
            hours = 24
            minutes = 0
        }
        // Minimum 1 minute
        if totalSeconds < 60 {
            totalSeconds = 60
            minutes = 1
        }
        duration = totalSeconds
    }
}
