import NIOHTTP1

struct InspectImagesEndpoint: Endpoint {
    typealias Body = NoBody
    typealias Response = ImageResponse
    var method: HTTPMethod = .GET

    let nameOrId: String

    var path: String {
        "images/\(nameOrId)/json"
    }

    struct ImageResponse: Codable {
        let Id: String
        let Parent: String
        let Os: String
        let Architecture: String
        let Created: String
        let RepoTags: [String]?
        let RepoDigests: [String]?
        let Size: Int
        // TODO: Add additional fields
    }
}
