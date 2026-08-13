import Foundation

struct StoredIdentity: Codable, Equatable {
    let address: String
    let publicKeyHex: String
    let createdAt: Date
}
