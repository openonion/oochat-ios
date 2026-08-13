import Foundation

protocol HostedAgentWebSocketTask: AnyObject, Sendable {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
}

extension URLSessionWebSocketTask: HostedAgentWebSocketTask {}

typealias HostedAgentWebSocketFactory = @Sendable (URL) -> any HostedAgentWebSocketTask
typealias HostedAgentEndpointResolver = @Sendable (String) async throws -> ResolvedEndpoint
