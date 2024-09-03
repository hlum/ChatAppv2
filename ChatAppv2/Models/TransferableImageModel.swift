

import SwiftUI
import UniformTypeIdentifiers

struct TransferableImage: Transferable {
    let image: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .image) { transferableImage in
            guard let data = transferableImage.image.jpegData(compressionQuality: 0.1) else {
                throw TransferError.conversionFailed
            }
            return data
        } importing: { data in
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return TransferableImage(image: uiImage)
        }
    }
    
    enum TransferError: Error {
        case importFailed
        case conversionFailed
    }
}
