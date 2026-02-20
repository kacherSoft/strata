import SwiftUI

// MARK: - Onboarding Page Configuration
// Edit this struct to customize each onboarding page
struct OnboardingPageConfig: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let footnote: String?
    let backgroundView: AnyView?
    
    init(
        id: Int,
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        footnote: String? = nil,
        backgroundView: AnyView? = nil
    ) {
        self.id = id
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.footnote = footnote
        self.backgroundView = backgroundView
    }
}

// MARK: - Onboarding Pages Definition
// Edit this array to add/remove/modify pages (max 5)
@MainActor
private let onboardingPages: [OnboardingPageConfig] = [
    OnboardingPageConfig(
        id: 0,
        icon: "checkmark.circle.fill",
        iconColor: .blue,
        title: "Welcome to TaskFlow Pro",
        description: "The fast, AI-powered task manager for macOS.\nOrganize your tasks with speed and intelligence."
    ),
    OnboardingPageConfig(
        id: 1,
        icon: "brain",
        iconColor: .purple,
        title: "AI Enhancement",
        description: "Add your Gemini or z.ai API key in Settings to unlock AI-powered task enhancement and smart suggestions.",
        footnote: "You can skip this and add later in Settings → AI Config"
    ),
    OnboardingPageConfig(
        id: 2,
        icon: "keyboard",
        iconColor: .green,
        title: "Global Shortcuts",
        description: "Press ⌘⇧N from anywhere to quickly add a task.\nPress ⌘⇧T to show the main window.\nPress ⌘⇧E to enhance selected text."
    )
]

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private var pages: [OnboardingPageConfig] {
        Array(onboardingPages.prefix(5))
    }
    
    private var totalSteps: Int { pages.count }
    
    var body: some View {
        ZStack {
            // Current page background (if provided)
            if let backgroundView = pages[safe: currentStep]?.backgroundView {
                backgroundView
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Page content
                ZStack {
                    ForEach(pages) { page in
                        OnboardingStepView(page: page)
                            .opacity(currentStep == page.id ? 1 : 0)
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Navigation dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(currentStep == index ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer().frame(width: 60)
                    }
                    
                    Spacer()
                    
                    Button(currentStep < totalSteps - 1 ? "Next" : "Get Started") {
                        if currentStep < totalSteps - 1 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentStep += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 520, height: 420)
        .background(.ultraThickMaterial)
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Step View
private struct OnboardingStepView: View {
    let page: OnboardingPageConfig
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundStyle(page.iconColor)
                .symbolRenderingMode(.hierarchical)
            
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            if let footnote = page.footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 50)
    }
}

// MARK: - Safe Array Access
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    OnboardingView()
}
