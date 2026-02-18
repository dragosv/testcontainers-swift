import Foundation
import NIOHTTP1

public protocol Endpoint {
    associatedtype Response: Codable
    associatedtype Body: Codable
    var path: String { get }
    var method: HTTPMethod { get }
    var body: Body? { get }
}

public extension Endpoint {
    var body: Body? {
        nil
    }
}

public protocol PipelineEndpoint: Endpoint {
    func map(data: String) throws -> Self.Response
}
