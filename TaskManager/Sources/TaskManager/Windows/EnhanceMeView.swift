import SwiftUI
import SwiftData
import AppKit

struct EnhanceMeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIModeModel.sortOrder) private var modes: [AIModeModel]
    
    @State private var aiService = AIService.shared
    @State private var originalText: String
    @State private var enhancedText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCopiedIndicator = false
    @State private var shouldFocusTextField = false
    
    let initialText: String
    var onDismiss: () -> Void
    
    init(initialText: String = "", onDismiss: @escaping () -> Void) {
        self.initialText = initialText
        self._originalText = State(initialValue: initialText)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(minWidth: 500, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .background(.ultraThickMaterial)
        .onAppear {
            aiService.loadDefaultMode(from: modelContext)
            shouldFocusTextField = true
        }
        .background(EnhanceMeShortcutHandler(onCycleMode: {
            aiService.cycleMode(in: modelContext)
        }))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Text("Enhance Me")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            modeSelector
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var modeSelector: some View {
        HStack(spacing: 12) {
            if let mode = aiService.currentMode {
                HStack(spacing: 6) {
                    Text(mode.name)
                        .fontWeight(.medium)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(mode.provider.displayName) \(mode.modelName)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No Mode")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Button(action: { aiService.cycleMode(in: modelContext) }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Tab")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .help("Cycle Mode (Tab)")
        }
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        HStack(spacing: 0) {
            originalColumn
            
            Divider()
            
            enhancedColumn
        }
    }
    
    private var originalColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            EnhanceTextEditor(
                text: $originalText,
                shouldFocus: shouldFocusTextField,
                onSubmit: { enhance() }
            )
            .padding(8)
            .background(.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var enhancedColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enhanced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if showCopiedIndicator {
                    Label("Copied!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            
            ZStack {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Enhancing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            errorMessage = nil
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if enhancedText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Press Enter or ⌘↩ to enhance")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $enhancedText)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .padding(8)
                        .background(.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: showCopiedIndicator)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            if let mode = aiService.currentMode, !aiService.isConfigured(for: mode.provider) {
                Label("Configure \(mode.provider.displayName) API key in Settings", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            Button("Enhance") {
                enhance()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || aiService.currentMode == nil || !isCurrentModeConfigured)
        }
        .padding()
    }
    
    private var isCurrentModeConfigured: Bool {
        guard let mode = aiService.currentMode else { return false }
        return aiService.isConfigured(for: mode.provider)
    }
    
    // MARK: - Actions
    
    private func enhance() {
        guard let mode = aiService.currentMode else { return }
        guard !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard isCurrentModeConfigured else { return }
        
        isLoading = true
        errorMessage = nil
        showCopiedIndicator = false
        
        Task {
            do {
                let result = try await aiService.enhance(text: originalText, mode: mode)
                enhancedText = result.enhancedText
                copyToClipboard(result.enhancedText)
            } catch let error as AIError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        withAnimation {
            showCopiedIndicator = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedIndicator = false
            }
        }
    }
}

// MARK: - Custom TextEditor with Enter handling

struct EnhanceMeShortcutHandler: NSViewRepresentable {
    var onCycleMode: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EnhanceMeShortcutNSView()
        view.onCycleMode = onCycleMode
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? EnhanceMeShortcutNSView)?.onCycleMode = onCycleMode
    }
}

final class EnhanceMeShortcutNSView: KeyEventMonitorNSView {
    var onCycleMode: (() -> Void)?

    override func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }
        if event.keyCode == 48 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] {
            onCycleMode?()
            return nil
        }
        return event
    }
}

struct EnhanceTextEditor: NSViewRepresentable {
    @Binding var text: String
    var shouldFocus: Bool
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        if shouldFocus && !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        weak var textView: NSTextView?
        var hasFocused = false
        
        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                if event?.modifierFlags.contains(.shift) == true {
                    return false
                }
                onSubmit()
                return true
            }
            return false
        }
    }
}
