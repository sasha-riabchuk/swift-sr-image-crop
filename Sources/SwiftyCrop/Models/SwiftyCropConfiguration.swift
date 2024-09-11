import CoreGraphics
import SwiftUI

/// `SwiftyCropConfiguration` is a struct that defines the configuration for cropping behavior.
public struct SwiftyCropConfiguration {
    public let maxMagnificationScale: CGFloat
    public let rotateImage: Bool
    public let zoomSensitivity: CGFloat
    public let panelBackgroundColor: Color
    public let doneButtonColor: Color
    public let cancelButtonColor: Color
    public let ratioButtonBackground: Color
    public let ratioButtonInnerColor: Color

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
        maxMagnificationScale: CGFloat = 4.0,
        rotateImage: Bool = false,
        zoomSensitivity: CGFloat = 3,
        panelBackgroundColor: Color = .gray,
        doneButtonColor: Color = .green,
        cancelButtonColor: Color = .red,
        ratioButtonBackground: Color = .cyan,
        ratioButtonInnerColor: Color = .white
    ) {
        self.maxMagnificationScale = maxMagnificationScale
        self.rotateImage = rotateImage
        self.zoomSensitivity = zoomSensitivity
        self.panelBackgroundColor = panelBackgroundColor
        self.doneButtonColor = doneButtonColor
        self.cancelButtonColor = cancelButtonColor
        self.ratioButtonBackground = ratioButtonBackground
        self.ratioButtonInnerColor = ratioButtonInnerColor
    }
}
