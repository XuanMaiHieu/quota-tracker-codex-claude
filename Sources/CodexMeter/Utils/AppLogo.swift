import SwiftUI

enum AppLogo {
    /// The bundled .app ships the PNGs in Contents/Resources; `swift run` only
    /// has SPM's resource bundle next to the build products.
    private static func url(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources")
    }

    static func image(named name: String) -> Image {
        if let url = url(named: name),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "app.dashed")
    }

    /// Sized NSImage for embedding inline in a menu bar `Text` via `Text(Image(nsImage:))` —
    /// a single Text is far more reliable for NSStatusItem sizing than composite HStack content.
    static func nsImage(named name: String, size: CGFloat) -> NSImage {
        let resolved: NSImage
        if let url = url(named: name),
           let loaded = NSImage(contentsOf: url) {
            resolved = loaded
        } else {
            resolved = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        resolved.size = NSSize(width: size, height: size)
        return resolved
    }
}
