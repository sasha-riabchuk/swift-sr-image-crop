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
                        MaskShapeView(aspectRatio: viewModel.aspectRatio)
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
        let gridColor: Color = .white
        let borderColor: Color = .white
        let borderThickness: CGFloat = 2.0

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
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
            HStack {
                ForEach(allowedAspectRatio, id: \.hashValue) { ratio in
                    VStack {
                        Rectangle()
                            .fill(.white)
                            .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
                            .frame(width: 40, height: 30)
                        Text(ratio.title)
                            .fontWeight(.bold)
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 50, height: 50)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(aspectRatio == ratio ? Color.red : configuration.ratioButtonInnerColor, lineWidth: 2)
                    }
                    .onTapGesture {
                        self.aspectRatio = ratio
                    }
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
                        .foregroundColor(configuration.cancelButtonColor)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(configuration.ratioButtonBackground)
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
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(configuration.doneButtonColor)
                        }
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(configuration.panelBackgroundColor)
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
