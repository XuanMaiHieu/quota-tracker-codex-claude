import SwiftUI

enum AppLogo {
    static func image(named name: String) -> Image {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "app.dashed")
    }

    /// Sized NSImage for embedding inline in a menu bar `Text` via `Text(Image(nsImage:))` —
    /// a single Text is far more reliable for NSStatusItem sizing than composite HStack content.
    static func nsImage(named name: String, size: CGFloat) -> NSImage {
        let resolved: NSImage
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources"),
           let loaded = NSImage(contentsOf: url) {
            resolved = loaded
        } else {
            resolved = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        resolved.size = NSSize(width: size, height: size)
        return resolved
    }
}
