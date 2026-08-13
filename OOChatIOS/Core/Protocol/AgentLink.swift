import Foundation

/// A link that hands someone an agent.
///
/// Adding an agent otherwise means typing a 64-character hex address or scanning
/// a QR code from a screen you are already looking at. Neither survives the way
/// an address actually reaches someone — in an email, a message, a web page. A
/// link does, and one tap is the whole flow.
///
///     openonion://agent/0x<64 hex>
///     openonion://agent/0x<64 hex>?name=Scriptbot
///
/// Parsing only. Whether the address is acceptable is `HostedAgentClient`'s
/// question, and adding it is `ChatViewModel.saveAgent`'s — this type exists so
/// neither of them has to know a URL format.
struct AgentLink: Equatable {
    let address: String
    let name: String?

    static let scheme = "openonion"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        // openonion://agent/0x… parses as host "agent" and path "/0x…". Accept the
        // address from either position: a link typed by hand, or one built by
        // string concatenation, can easily end up as openonion://0x… instead.
        let candidate: String?
        if url.host?.lowercased() == "agent" {
            candidate = url.path.split(separator: "/").first.map(String.init)
        } else {
            candidate = url.host
        }

        guard let address = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else { return nil }

        self.address = address
        self.name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "name" }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
