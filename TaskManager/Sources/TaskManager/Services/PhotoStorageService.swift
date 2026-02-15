import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class PhotoStorageService {
    static let shared = PhotoStorageService()
    
    private let fileManager = FileManager.default
    
    private var photosDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let photosDir = appSupport.appendingPathComponent("TaskFlowPro/Photos", isDirectory: true)

        if !fileManager.fileExists(atPath: photosDir.path) {
            do {
                try fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
            } catch {
                return fileManager.temporaryDirectory
            }
        }

        return photosDir
    }
    
    private init() {}
    
    /// Open a file picker and return selected photo URLs
    func pickPhotos(completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.title = "Select Photos"
        
        NSApp.activate(ignoringOtherApps: true)
        
        var floatingWindows: [(NSWindow, NSWindow.Level)] = []
        for window in NSApp.windows where window.level == .floating {
            floatingWindows.append((window, window.level))
            window.level = .normal
        }
        
        let presentingWindow: NSWindow?
        let mainWindow = WindowManager.shared.getMainWindow()
        if let mainWindow, mainWindow.attachedSheet == nil {
            presentingWindow = mainWindow
        } else if let keyWindow = NSApp.keyWindow, keyWindow.canBecomeKey {
            presentingWindow = keyWindow
        } else {
            presentingWindow = mainWindow?.attachedSheet ?? mainWindow
        }
        
        if let presentingWindow {
            panel.beginSheetModal(for: presentingWindow) { response in
                for (w, level) in floatingWindows { w.level = level }
                if response == .OK {
                    completion(panel.urls)
                }
            }
        } else {
            let response = panel.runModal()
            for (w, level) in floatingWindows { w.level = level }
            if response == .OK {
                completion(panel.urls)
            }
        }
    }
    
    /// Copy photos from source URLs to app storage and return the new paths
    func storePhotos(_ sourceURLs: [URL]) -> [String] {
        var storedPaths: [String] = []
        
        for sourceURL in sourceURLs {
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing { sourceURL.stopAccessingSecurityScopedResource() }
            }
            
            do {
                let fileName = "\(UUID().uuidString)_\(sourceURL.lastPathComponent)"
                let destinationURL = photosDirectory.appendingPathComponent(fileName)
                
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                storedPaths.append(destinationURL.path)
            } catch {
                continue
            }
        }
        
        return storedPaths
    }
    
    /// Delete a photo from app storage
    func deletePhoto(at path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            try fileManager.removeItem(at: url)
        } catch {
            return
        }
    }
    
    /// Check if photo exists at path
    func photoExists(at path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    func isStoredPhoto(_ url: URL) -> Bool {
        let dir = photosDirectory.standardizedFileURL.path
        return url.standardizedFileURL.path.hasPrefix(dir + "/")
    }
    
    func normalizeToStoredPaths(_ urls: [URL]) -> [String] {
        var result: [String] = []
        for url in urls {
            if isStoredPhoto(url) {
                result.append(url.path)
            } else {
                result.append(contentsOf: storePhotos([url]))
            }
        }
        return result
    }

    func storedPhotoPath(forFileName fileName: String) -> String? {
        let resolved = photosDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: resolved.path) ? resolved.path : nil
    }
}
