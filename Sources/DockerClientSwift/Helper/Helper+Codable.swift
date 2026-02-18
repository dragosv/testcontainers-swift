import Foundation

extension Encodable {
    func encode(with encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try encoder.encode(self)
    }
}

extension Decodable {
    static func decode(with decoder: JSONDecoder = JSONDecoder(), from data: Data) throws -> Self {
        try decoder.decode(Self.self, from: data)
    }

    static func decode(with decoder: JSONDecoder = JSONDecoder(), from string: String) throws -> Self {
        try decoder.decode(Self.self, from: string.data(using: .utf8)!)
    }
}
