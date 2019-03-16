import Foundation
import RobinHood

extension CDFeed: CoreDataCodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case favorite
        case favoriteCount
        case name
        case details = "description"
        case imageLink
        case status
        case likesCount
    }

    public func populate(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(String.self, forKey: .identifier)
        favorite = try container.decode(Bool.self, forKey: .favorite)
        favoriteCount = try container.decode(Int32.self, forKey: .favoriteCount)
        name = try container.decode(String.self, forKey: .name)
        details = try container.decodeIfPresent(String.self,
                                                forKey: .details)
        imageLink = try container.decodeIfPresent(String.self,
                                                  forKey: .imageLink)
        status = try container.decode(String.self, forKey: .status)
        likesCount = try container.decode(Int32.self, forKey: .likesCount)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(favorite, forKey: .favorite)
        try container.encode(favoriteCount, forKey: .favoriteCount)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(imageLink, forKey: .imageLink)
        try container.encode(status, forKey: .status)
        try container.encode(likesCount, forKey: .likesCount)
    }
}
