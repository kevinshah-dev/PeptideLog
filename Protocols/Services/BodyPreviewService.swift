import Foundation
import Supabase
import UIKit

struct BodyPreviewRequest: Encodable {
    let imageBase64: String
    let mimeType: String
    let protocolName: String
}

struct BodyPreviewResponse: Decodable {
    let imageBase64: String
    let disclaimer: String?
}

private struct BodyPreviewServiceError: Decodable {
    let error: String
}

enum BodyPreviewError: LocalizedError {
    case missingClient
    case invalidInputImage
    case emptyImageResponse
    case service(String)

    var errorDescription: String? {
        switch self {
        case .missingClient:
            "Sign in again before generating a preview."
        case .invalidInputImage:
            "That photo could not be prepared. Try a different image."
        case .emptyImageResponse:
            "The preview service did not return an image."
        case let .service(message):
            message
        }
    }
}

struct BodyPreviewService {
    let client: SupabaseClient?

    func generatePreview(
        imageData: Data,
        protocolName: String
    ) async throws -> Data {
        guard let client else { throw BodyPreviewError.missingClient }
        guard let preparedImageData = Self.preparedJPEGData(from: imageData) else {
            throw BodyPreviewError.invalidInputImage
        }

        let request = BodyPreviewRequest(
            imageBase64: preparedImageData.base64EncodedString(),
            mimeType: "image/jpeg",
            protocolName: protocolName
        )

        let response: BodyPreviewResponse

        do {
            response = try await client.functions.invoke(
                "body-preview",
                options: FunctionInvokeOptions(method: .post, body: request)
            )
        } catch let error as FunctionsError {
            throw Self.friendlyFunctionsError(error)
        }

        guard let outputData = Data(base64Encoded: response.imageBase64) else {
            throw BodyPreviewError.emptyImageResponse
        }

        return outputData
    }

    private static func friendlyFunctionsError(_ error: FunctionsError) -> Error {
        guard case let .httpError(_, data) = error,
              let serviceError = try? JSONDecoder().decode(BodyPreviewServiceError.self, from: data) else {
            return error
        }

        return BodyPreviewError.service(serviceError.error)
    }

    private static func preparedJPEGData(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }

        let maxLongSide: CGFloat = 1400
        let originalSize = image.size
        let longSide = max(originalSize.width, originalSize.height)
        let scale = longSide > maxLongSide ? maxLongSide / longSide : 1
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.86)
    }
}
