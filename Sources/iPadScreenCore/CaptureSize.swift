public struct PixelSize: Equatable, Sendable {
    public let width: Int
    public let height: Int
}

public enum CaptureSize {
    /// Claude downsamples anything past ~1568 px on the long edge, so more only costs
    /// tokens. https://docs.anthropic.com/en/docs/build-with-claude/vision
    public static let maxLongEdge = 1568

    public static func pixels(
        width: Double,
        height: Double,
        scale: Double,
        maxLongEdge: Int = maxLongEdge
    ) -> PixelSize {
        let pixelWidth = max(width, 0) * max(scale, 1)
        let pixelHeight = max(height, 0) * max(scale, 1)
        let longEdge = max(pixelWidth, pixelHeight)
        let shrink = longEdge > Double(maxLongEdge) ? Double(maxLongEdge) / longEdge : 1
        return PixelSize(
            width: max(1, Int((pixelWidth * shrink).rounded())),
            height: max(1, Int((pixelHeight * shrink).rounded()))
        )
    }
}
