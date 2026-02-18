import Foundation
import NIOHTTP1

struct ListServicesEndpoint: Endpoint {
    typealias Body = NoBody
    typealias Response = [Service.ServiceResponse]
    var method: HTTPMethod = .GET

    var path: String {
        "services"
    }
}
