import SwiftUI
import UIKit

public class CropViewModel: ObservableObject {
    private let maxMagnificationScale: CGFloat // The maximum allowed scale factor for image magnification.
    @Published var aspectRatio: AspectRatio // The shape of the mask used for cropping.
    
    var imageSizeInView: CGSize = .zero // The size of the image as displayed in the view.
    @Published var maskSize: CGSize = .zero // The size of the mask used for cropping. This is updated based on the mask shape and available space.
    @Published var scale: CGFloat = 1.0 // The current scale factor of the image.
    @Published var lastScale: CGFloat = 1.0 // The previous scale factor of the image.
    @Published var offset: CGSize = .zero // The current offset of the image.
    @Published var lastOffset: CGSize = .zero // The previous offset of the image.
    @Published var angle: Angle = .init(degrees: 0) // The current rotation angle of the image.
    @Published var lastAngle: Angle = .init(degrees: 0) // The previous rotation angle of the image.
    
    public init(
        maxMagnificationScale: CGFloat,
        aspectRatio: AspectRatio
    ) {
        self.maxMagnificationScale = maxMagnificationScale
        self.aspectRatio = aspectRatio
    }
    
    /**
     Updates the mask size based on the given size and mask shape.
     - Parameter size: The size to base the mask size calculations on.
     */
    private func updateMaskSize(for size: CGSize) {
        maskSize = aspectRatio.maskSize(for: size)
    }
    
    /**
     Updates the mask dimensions based on the size of the image in the view.
     - Parameter imageSizeInView: The size of the image as displayed in the view.
     */
    func updateMaskDimensions(for imageSizeInView: CGSize) {
        self.imageSizeInView = imageSizeInView
        updateMaskSize(for: imageSizeInView)
    }
    
    /**
     Calculates the maximum allowed offset for dragging the image.
     - Returns: A CGPoint representing the maximum x and y offsets.
     */
    func calculateDragGestureMax() -> CGPoint {
        let xLimit = max(0, ((imageSizeInView.width / 2) * scale) - (maskSize.width / 2))
        let yLimit = max(0, ((imageSizeInView.height / 2) * scale) - (maskSize.height / 2))
        return CGPoint(x: xLimit, y: yLimit)
    }
    
    /**
     Calculates the minimum and maximum allowed scale values for image magnification.
     - Returns: A tuple containing the minimum and maximum scale values.
     */
    func calculateMagnificationGestureMaxValues() -> (CGFloat, CGFloat) {
        let minScale = max(maskSize.width / imageSizeInView.width, maskSize.height / imageSizeInView.height)
        return (minScale, maxMagnificationScale)
    }
    
    /**
     Crops the given image to a square based on the current mask size and position.
     - Parameter image: The UIImage to crop.
     - Returns: A cropped UIImage, or nil if cropping fails.
     */
    func cropToSquare(_ image: UIImage) -> UIImage? {
        guard let orientedImage = image.correctlyOriented else { return nil }
        
        let cropRect = calculateCropRect(orientedImage)
        
        guard let cgImage = orientedImage.cgImage,
              let result = cgImage.cropping(to: cropRect)
        else {
            return nil
        }
        
        return UIImage(cgImage: result)
    }
    
    /**
     Crops the given image to a specific aspect ratio based on the current mask size and position.
     - Parameters:
       - image: The UIImage to crop.
       - aspectRatio: The aspect ratio to crop to.
     - Returns: A cropped UIImage, or nil if cropping fails.
     */
    func cropToAspectRatio(_ image: UIImage, aspectRatio: AspectRatio) -> UIImage? {
        guard let orientedImage = image.correctlyOriented else { return nil }
        
        // Calculate the crop rect for the given aspect ratio
        let cropRect = calculateCropRect(orientedImage)
        
        // Perform the cropping
        guard let cgImage = orientedImage.cgImage,
              let result = cgImage.cropping(to: cropRect)
        else {
            return nil
        }
        
        return UIImage(cgImage: result)
    }
    
    /**
     Rotates the given image by the specified angle.
     - Parameter image: The UIImage to rotate.
     - Parameter angle: The Angle to rotate the image by.
     - Returns: A rotated UIImage, or nil if rotation fails.
     */
    func rotate(_ image: UIImage, _ angle: Angle) -> UIImage? {
        guard let orientedImage = image.correctlyOriented,
              let cgImage = orientedImage.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter.straightenFilter(image: ciImage, radians: angle.radians),
              let output = filter.outputImage else { return nil }
        
        let context = CIContext()
        guard let result = context.createCGImage(output, from: output.extent) else { return nil }
        
        return UIImage(cgImage: result)
    }
    
    /**
     Calculates the rectangle to use for cropping the image based on the current mask size, scale, and offset.
     - Parameter orientedImage: The correctly oriented UIImage to calculate the crop rect for.
     - Returns: A CGRect representing the area to crop from the original image.
     */
    private func calculateCropRect(_ orientedImage: UIImage) -> CGRect {
        let factor = min(
            orientedImage.size.width / imageSizeInView.width,
            orientedImage.size.height / imageSizeInView.height
        )
        let centerInOriginalImage = CGPoint(
            x: orientedImage.size.width / 2,
            y: orientedImage.size.height / 2
        )
        
        let cropSizeInOriginalImage = CGSize(
            width: (maskSize.width * factor) / scale,
            height: (maskSize.height * factor) / scale
        )
        
        let offsetX = offset.width * factor / scale
        let offsetY = offset.height * factor / scale
        
        let cropRectX = (centerInOriginalImage.x - cropSizeInOriginalImage.width / 2) - offsetX
        let cropRectY = (centerInOriginalImage.y - cropSizeInOriginalImage.height / 2) - offsetY
        
        return CGRect(
            origin: CGPoint(x: cropRectX, y: cropRectY),
            size: cropSizeInOriginalImage
        )
    }
}

private extension UIImage {
    /**
     A UIImage instance with corrected orientation.
     If the instance's orientation is already `.up`, it simply returns the original.
     - Returns: An optional UIImage that represents the correctly oriented image.
     */
    var correctlyOriented: UIImage? {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}

private extension CIFilter {
    /**
     Creates the straighten filter.
     - Parameters:
     - inputImage: The CIImage to use as an input image
     - radians: An angle in radians
     - Returns: A generated CIFilter.
     */
    static func straightenFilter(image: CIImage, radians: Double) -> CIFilter? {
        let angle: Double = radians != 0 ? -radians : 0
        guard let filter = CIFilter(name: "CIStraightenFilter") else {
            return nil
        }
        filter.setDefaults()
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(angle, forKey: kCIInputAngleKey)
        return filter
    }
}
