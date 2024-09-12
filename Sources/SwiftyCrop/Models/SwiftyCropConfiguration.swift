import CoreGraphics
import SwiftUI

/// `SwiftyCropConfiguration` is a struct that defines the configuration for cropping behavior.
public struct SwiftyCropConfiguration {
    public let maxMagnificationScale: CGFloat
    public let rotateImage: Bool
    public let zoomSensitivity: CGFloat
    public let backgroundColor: Color
    public let fontColor: Color
    public let previewRectangleColor: Color
    public let selectionColor: Color
    public let primaryColor: Color
    public let secondaryBackgroundColor: Color

    /// Creates a new instance of `SwiftyCropConfiguration`.
    ///
    /// - Parameters:
    ///   - maxMagnificationScale: The maximum scale factor that the image can be magnified while cropping.
    ///                            Defaults to `4.0`.
    ///   - cropImageCircular: Option to enable circular crop.
    ///                            Defaults to `false`.
    ///   - rotateImage: Option to rotate image.
    ///                            Defaults to `false`.
    ///   - zoomSensitivity: Sensitivity when zooming. Default is `1.0`. Decrease to increase sensitivity.
    ///
    ///   - rectAspectRatio: The aspect ratio to use when a `.rectangle` mask shape is used. Defaults to `4:3`.
    public init(
        maxMagnificationScale: CGFloat = 5.0,
        rotateImage: Bool = false,
        zoomSensitivity: CGFloat = 6,
        backgroundColor: Color = .red,
        fontColor: Color = .white,
        previewRectangleColor: Color = .blue,
        selectionColor: Color = .green,
        primaryColor: Color = .orange,
        secondaryBackgroundColor: Color = .gray
    ) {
        self.maxMagnificationScale = maxMagnificationScale
        self.rotateImage = rotateImage
        self.zoomSensitivity = zoomSensitivity
        self.backgroundColor = backgroundColor
        self.fontColor = fontColor
        self.previewRectangleColor = previewRectangleColor
        self.selectionColor = selectionColor
        self.primaryColor = primaryColor
        self.secondaryBackgroundColor = secondaryBackgroundColor
    }
}
