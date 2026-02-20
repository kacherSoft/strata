import SwiftUI

// MARK: - Reminder Action Popover
public struct ReminderActionPopover: View {
    @Binding var isPresented: Bool
    let currentDuration: TimeInterval
    let mode: Mode
    let onSetDuration: (TimeInterval) -> Void
    let onRemoveReminder: (() -> Void)?
    
    @State private var hours: Int
    @State private var minutes: Int
    
    private let minuteOptions = Array(0...59)
    
    public enum Mode {
        case create
        case edit
    }
    
    private let presets: [(String, TimeInterval)] = [
        ("5 min", 5 * 60),
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("1 hr", 60 * 60),
        ("2 hr", 2 * 60 * 60),
    ]
    
    public init(
        isPresented: Binding<Bool>,
        currentDuration: TimeInterval,
        mode: Mode,
        onSetDuration: @escaping (TimeInterval) -> Void,
        onRemoveReminder: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.currentDuration = currentDuration
        self.mode = mode
        let total = Int(currentDuration)
        self._hours = State(initialValue: total / 3600)
        self._minutes = State(initialValue: (total % 3600) / 60)
        self.onSetDuration = onSetDuration
        self.onRemoveReminder = onRemoveReminder
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: mode == .edit ? "bell.fill" : "bell.badge")
                    .foregroundStyle(mode == .edit ? .orange : .secondary)
                Text(mode == .edit ? "Edit Reminder" : "Set Reminder")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            
            Divider()
            
            // Quick presets
            Text(mode == .edit ? "Restart Timer" : "Quick Set")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                ForEach(presets, id: \.1) { label, value in
                    Button {
                        onSetDuration(value)
                        isPresented = false
                    } label: {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .modifier(LiquidGlassModifier(style: .badge))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom time
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Picker("", selection: $hours) {
                        ForEach(0...24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .frame(width: 55)
                    Text("hr")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Picker("", selection: $minutes) {
                        ForEach(minuteOptions, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .frame(width: 55)
                    Text("min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    let duration = TimeInterval(hours * 3600 + minutes * 60)
                    let clamped = max(60, min(duration, 24 * 3600))
                    onSetDuration(clamped)
                    isPresented = false
                } label: {
                    Text("Set")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Remove reminder (only in edit mode)
            if mode == .edit, let onRemoveReminder {
                Divider()
                
                Button(role: .destructive) {
                    onRemoveReminder()
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "bell.slash")
                        Text("Remove Reminder")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
