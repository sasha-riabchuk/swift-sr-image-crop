//
//  CroppingControllPanel.swift
//  
//
//  Created by Sasha Riabchuk on 11.09.2024.
//

import Foundation
import SwiftUI
import UIKit

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
        VStack(spacing: 15) {
            HStack {
                ForEach(allowedAspectRatio, id: \.hashValue) { ratio in
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(configuration.previewRectangleColor)
                            .aspectRatio(ratio.size.width / ratio.size.height, contentMode: .fit)
                            .frame(width: 30, height: 20)
                        Text(ratio.title)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 50, height: 50)
                    .padding(8)
                    .background {
                        aspectRatio == ratio ? configuration.selectionColor : configuration.backgroundColor
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
                        .foregroundColor(configuration.fontColor)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(configuration.backgroundColor)
                        }
                }
                
                Spacer()
                
                Text("Choose ratio")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(configuration.fontColor)
                    .padding(10)
                
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
                        .foregroundColor(configuration.fontColor)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(configuration.primaryColor)
                        }
                }
                .foregroundColor(.white)
            }
            .padding(.horizontal)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(configuration.secondaryBackgroundColor)
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
