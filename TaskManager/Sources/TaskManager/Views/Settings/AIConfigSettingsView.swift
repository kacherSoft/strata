import SwiftUI

struct AIConfigSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "cpu")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("AI Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Coming in Phase 3")
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.1), in: Capsule())
            
            Text("Configure AI providers, API keys,\nand model settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
