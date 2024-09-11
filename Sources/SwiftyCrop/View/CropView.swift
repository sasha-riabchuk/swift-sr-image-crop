import SwiftUI

struct CropView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CropViewModel
    
    private let image: UIImage
    private let configuration: SwiftyCropConfiguration
    private let onComplete: (UIImage?) -> Void
    private let localizableTableName: String
    
    init(
        image: UIImage,
        aspectRatio: AspectRatio,
        configuration: SwiftyCropConfiguration,
        onComplete: @escaping (UIImage?) -> Void
    ) {
        self.image = image
        self.configuration = configuration
        self.onComplete = onComplete
        _viewModel = StateObject(
            wrappedValue: CropViewModel(
                maxMagnificationScale: configuration.maxMagnificationScale,
                aspectRatio: aspectRatio
            )
        )
        localizableTableName = "Localizable"
    }
    
    var body: some View {
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
                    .opacity(0.5)
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
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(viewModel.angle)
                    .scaleEffect(viewModel.scale)
                    .offset(viewModel.offset)
                    .mask(
                        MaskShapeView(aspectRatio: viewModel.aspectRatio)
                            .frame(width: viewModel.maskSize.width, height: viewModel.maskSize.height)
                    )
                    .overlay {
                        MaskShapeView(aspectRatio: viewModel.aspectRatio)
                            .frame(width: viewModel.maskSize.width, height: viewModel.maskSize.height)
                    }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(configuration.rotateImage ? rotationGesture : nil)
            .animation(.easeIn, value: viewModel.aspectRatio)

            CroppingControllPanel(
                onComplete: onComplete,
                image: image,
                configuration: configuration,
                localizableTableName: localizableTableName,
                viewModel: viewModel,
                aspectRatio: $viewModel.aspectRatio
            )
        }
    }
    
    private func updateOffset() {
        let maxOffsetPoint = viewModel.calculateDragGestureMax()
        let newX = min(max(viewModel.offset.width, -maxOffsetPoint.x), maxOffsetPoint.x)
        let newY = min(max(viewModel.offset.height, -maxOffsetPoint.y), maxOffsetPoint.y)
        viewModel.offset = CGSize(width: newX, height: newY)
        viewModel.lastOffset = viewModel.offset
    }
    
    private struct MaskShapeView: View {
        let aspectRatio: AspectRatio
        let lineWidth: CGFloat = 1.0
        let gridColor: Color = .green // Grid line color
        let borderColor: Color = .green // Border color for the mask
        let borderThickness: CGFloat = 2.0 // Thickness for the border

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Main rectangle to act as the mask with border
                    Rectangle()
                        .fill(.green.opacity(0.1))
                        .aspectRatio(aspectRatio.size.width / aspectRatio.size.height, contentMode: .fit)
                        .foregroundColor(.clear) // The mask area is transparent
                        .border(borderColor, width: borderThickness) // Add border to the mask
                    // Add a grid on top of the transparent rectangle
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
                    .stroke(gridColor, lineWidth: lineWidth) // Style grid lines
                    
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
    private let configuration: SwiftyCropConfiguration
    private var viewModel: CropViewModel
    
    @Binding private var aspectRatio: AspectRatio
    
    public init(onComplete: @escaping (UIImage?) -> Void, image: UIImage, configuration: SwiftyCropConfiguration, localizableTableName: String, viewModel: CropViewModel, aspectRatio: Binding<AspectRatio>) {
        self.onComplete = onComplete
        self.image = image
        self.localizableTableName = localizableTableName
        self.configuration = configuration
        self.viewModel = viewModel
        _aspectRatio = aspectRatio
    }
    
    public var body: some View {
        VStack {
            HStack {
                ForEach(AspectRatio.allCases, id: \.hashValue) { ratio in
                    Text("\(ratio.size)")
                        .onTapGesture {
                            self.aspectRatio = ratio
                        }
                        .foregroundColor(aspectRatio == ratio ? .red : .white)
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
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(.gray)
                        }
                }
                
                Button {
                    onComplete(cropImage())
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(.green)
                        }
                }
                .foregroundColor(.white)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(.brown)
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
