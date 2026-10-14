import CoreGraphics

// Does a capture show nothing but black? QuickTime shows black while the iPad is locked,
// asleep or unplugged, and Claude would otherwise read that as an empty page.
public enum BlankFrame {
    /// The capture is shrunk to this many grey samples first. Fine enough that a single
    /// pen stroke on a dark page still lifts a few samples clear of black.
    public static let sampleWidth = 128
    public static let sampleHeight = 96
    /// Video black plus compression noise stays under this (0–255).
    static let darkLimit: UInt8 = 32
    /// Up to this share of samples may be brighter and the frame still counts as black.
    static let brightAllowance = 0.002

    public static func isBlank(_ image: CGImage) -> Bool {
        luminance(of: image).map(isBlank(luminance:)) ?? false
    }

    static func isBlank(luminance samples: [UInt8]) -> Bool {
        guard !samples.isEmpty else { return false }
        let bright = samples.lazy.filter { $0 > darkLimit }.count
        return Double(bright) <= Double(samples.count) * brightAllowance
    }

    static func luminance(of image: CGImage) -> [UInt8]? {
        var samples = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)
        let drawn = samples.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: sampleWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            return true
        }
        return drawn ? samples : nil
    }
}
