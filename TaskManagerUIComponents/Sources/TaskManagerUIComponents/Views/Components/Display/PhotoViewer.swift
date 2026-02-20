import SwiftUI

// MARK: - Photo Viewer (Fullscreen)
public struct PhotoViewer: View {
    let photos: [URL]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var showArrows = true

    public init(photos: [URL], selectedIndex: Binding<Int>) {
        self.photos = photos
        self._selectedIndex = selectedIndex
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Main photo with swipe navigation
            TabView(selection: $selectedIndex) {
                ForEach(0..<photos.count, id: \.self) { index in
                    AsyncImage(url: photos[index]) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.system(size: 40))
                                Text("Failed to load photo")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }

            // Navigation arrows
            if showArrows {
                HStack {
                    if selectedIndex > 0 {
                        Button {
                            withAnimation {
                                selectedIndex -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .liquidGlass(.circleButton)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if selectedIndex < photos.count - 1 {
                        Button {
                            withAnimation {
                                selectedIndex += 1
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .liquidGlass(.circleButton)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }

            // Top bar: Close + Page indicator
            VStack {
                HStack {
                    // Page indicator
                    Text("\(selectedIndex + 1) / \(photos.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlass(.badge)

                    Spacer()

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .liquidGlass(.circleButton)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                Spacer()
            }
        }
        .onAppear {
            // Auto-hide arrows after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.linear(duration: 0.3)) {
                    showArrows = false
                }
            }
        }
        // Show arrows on tap
        .gesture(
            TapGesture()
                .onEnded {
                    showArrows.toggle()
                }
        )
    }
}

// MARK: - Photo Thumbnail
public struct PhotoThumbnail: View {
    let url: URL
    let isSelected: Bool

    public init(url: URL, isSelected: Bool = false) {
        self.url = url
        self.isSelected = isSelected
    }

    public var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 60, height: 60)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
                    .liquidGlass(.init(thickness: .ultraThin, variant: .default, cornerRadius: 8))
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.blue, lineWidth: 2)
            }
        }
    }
}

// MARK: - Photo Thumbnail Strip
public struct PhotoThumbnailStrip: View {
    let photos: [URL]
    let onRemove: ((URL) -> Void)?
    @State private var selectedIndex = 0
    @State private var showViewer = false

    public init(photos: [URL], onRemove: ((URL) -> Void)? = nil) {
        self.photos = photos
        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<photos.count, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        PhotoThumbnail(url: photos[index])
                            .onTapGesture {
                                selectedIndex = index
                                showViewer = true
                            }
                        
                        if onRemove != nil {
                            Button {
                                onRemove?(photos[index])
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(.black.opacity(0.6)))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 70)
        .sheet(isPresented: $showViewer) {
            PhotoViewer(photos: photos, selectedIndex: $selectedIndex)
                .frame(minWidth: 600, minHeight: 400)
                .background(.black)
        }
    }
}
