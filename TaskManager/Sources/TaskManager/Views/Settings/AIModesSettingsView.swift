import SwiftUI

struct AIModesSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("AI Modes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Coming in Phase 3")
                .font(.headline)
                .foregroundStyle(.purple)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.purple.opacity(0.1), in: Capsule())
            
            Text("Create custom AI enhancement modes\nwith your own prompts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
