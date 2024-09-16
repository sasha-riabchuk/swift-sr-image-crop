import SwiftUI

public struct CropView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CropViewModel
    
    private let image: UIImage
    private let configuration: SwiftyCropConfiguration
    private let allowedAspectRatio: [AspectRatio]
    private let onComplete: (UIImage?) -> Void
    private let localizableTableName: String
    
    @State var imageOpacity: Int = 1
    
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
                    .opacity(imageOpacity)
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
        .background(configuration.backgroundColor)
        .onDisappear(perform: {
            imageOpacity = 0
        })
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
