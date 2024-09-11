import Foundation

public enum AspectRatio: CaseIterable {
    case nineBySixteen, oneByOne, fourByThree, threeByFour, sixteenByNine
    
    public var size: CGSize {
        switch self {
        case .nineBySixteen: return CGSize(width: 9, height: 16)
        case .oneByOne: return CGSize(width: 1, height: 1)
        case .fourByThree: return CGSize(width: 4, height: 3)
        case .threeByFour: return CGSize(width: 3, height: 4)
        case .sixteenByNine: return CGSize(width: 16, height: 9)
        }
    }
    
    public func maskSize(for size: CGSize) -> CGSize {
            let aspect = self.size.width / self.size.height
            let maxWidth = size.width
            let maxHeight = size.height

            switch self {
            case .oneByOne:
                let dimension = min(maxWidth, maxHeight)
                return CGSize(width: dimension, height: dimension)
            case .nineBySixteen, .sixteenByNine, .fourByThree, .threeByFour:
                if maxWidth / maxHeight > aspect {
                    return CGSize(width: maxHeight * aspect, height: maxHeight)
                } else {
                    return CGSize(width: maxWidth, height: maxWidth / aspect)
                }
            }
        }
}
