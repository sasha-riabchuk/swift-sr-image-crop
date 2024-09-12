import SwiftUI

public struct CropView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CropViewModel
    
    private let image: UIImage
    private let configuration: SwiftyCropConfiguration
    private let allowedAspectRatio: [AspectRatio]
    private let onComplete: (UIImage?) -> Void
    private let localizableTableName: String
    
    public init(
        image: UIImage,
        aspectRatio: AspectRatio,
        allowedAspectRatio: [AspectRatio] = AspectRatio.allCases,
        configuration: SwiftyCropConfiguration,
        onComplete: @escaping (UIImage?) -> Void
    ) {
        self.image = image
        self.configuration = configuration
        self.allowedAspectRatio = allowedAspectRatio
        self.onComplete = onComplete
        _viewModel = StateObject(
            wrappedValue: CropViewModel(
                maxMagnificationScale: configuration.maxMagnificationScale,
                aspectRatio: aspectRatio
            )
        )
        localizableTableName = "Localizable"
    }
    
    public var body: some View {
        let magnificationGesture = MagnificationGesture()
            .onChanged { value in
                let sensitivity: CGFloat = 0.1 * configuration.zoomSensitivity
                let scaledValue = (value.magnitude - 1) * sensitivity + 1
                
                let maxScaleValues = viewModel.calculateMagnificationGestureMaxValues()
                viewModel.scale = min(max(scaledValue * viewModel.lastScale, maxScaleValues.0), maxScaleValues.1)
                
                updateOffset()
            }
            .onEnded { _ in
                viewModel.lastScale = viewModel.scale
                viewModel.lastOffset = viewModel.offset
            }
        
        let dragGesture = DragGesture()
            .onChanged { value in
                viewModel.isDragging = true
                let maxOffsetPoint = viewModel.calculateDragGestureMax()
                let newX = min(
                    max(value.translation.width + viewModel.lastOffset.width, -maxOffsetPoint.x),
                    maxOffsetPoint.x
                )
                let newY = min(
                    max(value.translation.height + viewModel.lastOffset.height, -maxOffsetPoint.y),
                    maxOffsetPoint.y
                )
                viewModel.offset = CGSize(width: newX, height: newY)
            }
            .onEnded { _ in
                viewModel.lastOffset = viewModel.offset
                viewModel.isDragging = false
            }
        
        let rotationGesture = RotationGesture()
            .onChanged { value in
                viewModel.angle = value
            }
            .onEnded { _ in
                viewModel.lastAngle = viewModel.angle
            }
        
        VStack {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(viewModel.angle)
                    .scaleEffect(viewModel.scale)
                    .offset(viewModel.offset)
                    .overlay(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    viewModel.updateMaskDimensions(for: geometry.size)
                                }
                                .onChange(of: viewModel.aspectRatio, perform: { _ in
                                    viewModel.updateMaskDimensions(for: geometry.size)
                                })
                        }
                    )
                    .overlay {
                        MaskShapeView(aspectRatio: $viewModel.aspectRatio)
                            .frame(width: viewModel.maskSize.width, height: viewModel.maskSize.height)
                    }
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(configuration.rotateImage ? rotationGesture : nil)
            .animation(.default, value: viewModel.aspectRatio)
            .animation(.default, value: viewModel.offset)

            CroppingControllPanel(
                onComplete: onComplete,
                image: image,
                configuration: configuration,
                localizableTableName: localizableTableName,
                allowedAspectRatio: allowedAspectRatio,
                viewModel: viewModel,
                aspectRatio: $viewModel.aspectRatio
            )
        }
        .background(CustomColor.blackBackgroundColor)
    }
    
    private func updateOffset() {
        let maxOffsetPoint = viewModel.calculateDragGestureMax()
        let newX = min(max(viewModel.offset.width, -maxOffsetPoint.x), maxOffsetPoint.x)
        let newY = min(max(viewModel.offset.height, -maxOffsetPoint.y), maxOffsetPoint.y)
        viewModel.offset = CGSize(width: newX, height: newY)
        viewModel.lastOffset = viewModel.offset
    }
    
    private struct MaskShapeView: View {
        @Binding var aspectRatio: AspectRatio
        let lineWidth: CGFloat = 1.0
        let gridColor: Color = .white.opacity(0.7)
        let borderColor: Color = .white
        let borderThickness: CGFloat = 1.5
        @State private var drawProgress: CGFloat = 0.0

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Mask shape with border
                    Rectangle()
                        .aspectRatio(aspectRatio.size.width / aspectRatio.size.height, contentMode: .fit)
                        .foregroundColor(.clear)
                        .border(borderColor, width: borderThickness)
                        .animation(.easeInOut(duration: 0.5), value: aspectRatio)

                    // Grid overlay with animated drawing
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        // Vertical grid lines
                        for i in 1..<3 {
                            let xPos = width / 3 * CGFloat(i)
                            path.move(to: CGPoint(x: xPos, y: 0))
                            path.addLine(to: CGPoint(x: xPos, y: height))
                        }

                        // Horizontal grid lines
                        for i in 1..<3 {
                            let yPos = height / 3 * CGFloat(i)
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: width, y: yPos))
                        }
                    }
                    .trim(from: 0, to: drawProgress)
                    .stroke(gridColor, lineWidth: lineWidth)
                    .onAppear {
                        // Initial animation to draw grid when the view appears
                        withAnimation(.linear(duration: 0.5)) {
                            drawProgress = 1.0
                        }
                    }
                    .onChange(of: aspectRatio) { _ in
                        // Re-trigger animation when aspect ratio changes
                        withAnimation(.linear(duration: 0.5)) {
                            drawProgress = 0.0 // Reset the drawing
                        }
                        withAnimation(.linear(duration: 0.5).delay(0.7)) {
                            drawProgress = 1.0 // Animate grid drawing again
                        }
                    }
                }
                .aspectRatio(aspectRatio.size.width / aspectRatio.size.height, contentMode: .fit)
            }
        }
    }
}

#Preview {
    CropView(image: .init(systemName: "person")!,
             aspectRatio: .fourByThree,
             configuration: .init())
    { _ in
        debugPrint("Image was cropped")
    }
}

public struct CroppingControllPanel: View {
    @Environment(\.dismiss) private var dismiss
    private let onComplete: (UIImage?) -> Void
    private let image: UIImage
    private let localizableTableName: String
    private let allowedAspectRatio: [AspectRatio]
    private let configuration: SwiftyCropConfiguration
    private var viewModel: CropViewModel
    
    @Binding private var aspectRatio: AspectRatio
    
    public init(
        onComplete: @escaping (UIImage?) -> Void,
        image: UIImage,
        configuration: SwiftyCropConfiguration,
        localizableTableName: String,
        allowedAspectRatio: [AspectRatio],
        viewModel: CropViewModel,
        aspectRatio: Binding<AspectRatio>
    ) {
        self.onComplete = onComplete
        self.image = image
        self.localizableTableName = localizableTableName
        self.allowedAspectRatio = allowedAspectRatio
        self.configuration = configuration
        self.viewModel = viewModel
        _aspectRatio = aspectRatio
    }
    
    public var body: some View {
        VStack {
            Text("Choose ratio")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(CustomColor.whiteMainColor)
                .padding(10)
            
            HStack {
                ForEach(allowedAspectRatio, id: \.hashValue) { ratio in
                    VStack {
                        Rectangle()
                            .fill(CustomColor.blueColor)
                            .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
                            .frame(width: 30, height: 20)
                        Text(ratio.title)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 50, height: 50)
                    .padding(8)
                    .background {
                        aspectRatio == ratio ? CustomColor.oceanicMainColor : CustomColor.blackBackgroundColor
                    }
                    .cornerRadius(12)
                    .onTapGesture {
                        self.aspectRatio = ratio
                    }
                    .animation(.default, value: aspectRatio)
                }
            }
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .fontWeight(.bold)
                        .foregroundColor(CustomColor.whiteMainColor)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(CustomColor.blackBackgroundColor)
                        }
                }
                
                Spacer()
                
                Button {
                    onComplete(cropImage())
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .fontWeight(.bold)
                        .foregroundColor(CustomColor.whiteMainColor)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(CustomColor.goldColor)
                        }
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(CustomColor.grayCellBackgroundColor)
    }
    
    private func cropImage() -> UIImage? {
        var editedImage: UIImage = image
        if configuration.rotateImage {
            if let rotatedImage: UIImage = viewModel.rotate(
                editedImage,
                viewModel.lastAngle
            ) {
                editedImage = rotatedImage
            }
        }

        switch aspectRatio {
        case .oneByOne:
            return viewModel.cropToSquare(editedImage)
        case .nineBySixteen, .sixteenByNine, .fourByThree, .threeByFour:
            return viewModel.cropToAspectRatio(editedImage, aspectRatio: aspectRatio)
        }
    }
}

public enum CustomColor {
    public static var blackBackgroundColor = Color(hex: "17181E")
    public static var grayCellBackgroundColor = Color(hex: "22252D")
    public static var grayContainerBackgroundColor = Color(hex: "1A1D22")
    public static var whiteMainColor = Color(hex: "F8F8FF")
    public static var oceanicMainColor = Color(hex: "0A7273")
    public static var redColor = Color(hex: "FF4B59")

    public static var pinkColor = Color(hex: "DD2A7B")
    public static var purpleColor = Color(hex: "A300FF")
    public static var lightPurpleColor = Color(hex: "A300FF")
    public static var greenColor = Color(hex: "00D166")
    public static var blueColor = Color(hex: "4AB8FF")
    public static var goldColor = Color(hex: "FDA521")
    public static var blueSecondaryColor = Color(hex: "2596be")

    public static var successMainColor = Color(hex: "00DF80")
    public static var successAlertColor = Color(hex: "7DFFC7")
    public static var warningMainColor = Color(hex: "FFD21F")
    public static var warningAlertColor = Color(hex: "FDE069")
    public static var errorMainColor = Color(hex: "F04349")
    public static var errorAlertColor = Color(hex: "FF8F93")

    public static var facebookColor = Color(hex: "1877F2")
    public static var instagramColor = Color(hex: "1877F2")
    public static var telegramColor = Color(hex: "229ED9")
}

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
