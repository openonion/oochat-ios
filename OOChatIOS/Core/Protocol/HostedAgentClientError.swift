import Foundation

enum HostedAgentClientError: LocalizedError {
    case invalidAddress
    case invalidURL(String)
    case badFrame
    case server(String)
    case closed
    case timeout
    case busy

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "That doesn't look like an agent address. It should start with 0x followed by 64 characters."
        case .invalidURL(let url):
            return "Couldn't reach the agent at \(url). Check that the address is correct and the agent is online."
        case .badFrame:
            return "The agent sent a reply the app couldn't understand. Try again."
        case .server(let message):
            let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "The agent reported a problem but didn't say what went wrong. Try again."
                : "The agent reported a problem: \(detail)"
        case .closed:
            return "The connection closed before the agent replied. Try again."
        case .timeout:
            return "The agent didn't reply in time. Try again."
        case .busy:
            return "The agent is still working on your previous message in this conversation. Wait for it to finish, then try again."
        }
    }

    static func isConnectivityFailure(_ error: Error) -> Bool {
        guard let clientError = error as? HostedAgentClientError else {
            return false
        }
        switch clientError {
        case .closed, .timeout, .invalidURL:
            return true
        case .invalidAddress, .badFrame, .server, .busy:
            return false
        }
    }
}
