import Foundation

/// Result of checking whether an agent can be reached.
/// `unknown` leaves the last known presence unchanged.
enum AgentAvailability: Equatable, Sendable {
    case online
    case offline
    case unknown
}

struct SavedAgent: Identifiable, Equatable {
    let id: String
    var name: String
    var address: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        address: String,
        name: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.address = address
        self.name = name ?? Self.defaultName(for: address)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func defaultName(for address: String) -> String {
        guard address.count > 16 else {
            return address.isEmpty ? "Agent" : "Agent \(address)"
        }
        return "Agent \(address.prefix(8))...\(address.suffix(6))"
    }
}
