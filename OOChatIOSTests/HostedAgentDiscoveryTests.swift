import Foundation
import XCTest
@testable import OOChatIOS

private final class DiscoveryURLProtocol: URLProtocol {
    static var responses: [String: Result<(statusCode: Int, data: Data), Error>] = [:]

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let result = Self.responses[url.absoluteString] else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        switch result {
        case .success(let response):
            guard let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(
                self,
                didReceive: httpResponse,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private actor DiscoverySocketRecorder {
    private(set) var sentMessages: [URLSessionWebSocketTask.Message] = []

    func record(_ message: URLSessionWebSocketTask.Message) {
        sentMessages.append(message)
    }
}

private final class DiscoveryWebSocketTask: HostedAgentWebSocketTask, @unchecked Sendable {
    let recorder = DiscoverySocketRecorder()
    private let receiveResult: Result<URLSessionWebSocketTask.Message, Error>

    init(receiveResult: Result<URLSessionWebSocketTask.Message, Error>) {
        self.receiveResult = receiveResult
    }

    func resume() {}

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        await recorder.record(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try receiveResult.get()
    }
}
final class HostedAgentDiscoveryTests: XCTestCase {
    private let endpointA = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    func testAgentInfoDecodesDirectAndRelayAdvertisedSkills() throws {
        let direct = try JSONDecoder().decode(AgentInfo.self, from: Data("""
        {
          "address": "\(endpointA)",
          "name": "Local agent",
          "online": true,
          "skills": [
            {"name": "review", "description": "Review the current changes", "location": "project"}
          ]
        }
        """.utf8))
        let relay = try JSONDecoder().decode(AgentInfo.self, from: Data("""
        {
          "endpoints": ["https://agent.example"],
          "online": false,
          "profile": {
            "alias": "Relay agent",
            "skills": [
              {"name": "commit", "description": "Create a commit"}
            ]
          }
        }
        """.utf8))

        XCTAssertEqual(
            direct.advertisedSkills,
            [AgentSkill(name: "review", description: "Review the current changes", location: "project")]
        )
        XCTAssertEqual(
            relay.advertisedSkills,
            [AgentSkill(name: "commit", description: "Create a commit")]
        )
        XCTAssertEqual(direct.advertisedName, "Local agent")
        XCTAssertEqual(relay.advertisedName, "Relay agent")
        XCTAssertEqual(direct.online, true)
        XCTAssertEqual(relay.online, false)
    }

    func testAgentInfoIgnoresBlankNamesAndFallsBackToRelayAlias() throws {
        let info = try JSONDecoder().decode(AgentInfo.self, from: Data("""
        {
          "name": "   ",
          "profile": {"alias": "  Relay agent  "}
        }
        """.utf8))

        XCTAssertEqual(info.advertisedName, "Relay agent")
    }

    func testAgentInfoTreatsMissingSkillDescriptionsAsEmpty() throws {
        let info = try JSONDecoder().decode(AgentInfo.self, from: Data("""
        {"skills": [{"name": "status"}]}
        """.utf8))

        XCTAssertEqual(info.advertisedSkills, [AgentSkill(name: "status")])
    }

    func testAgentAvailabilityUsesDirectInfoAndRelayLookupOnlineFlag() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DiscoveryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let directURL = "http://local.test/info"
        DiscoveryURLProtocol.responses = [
            directURL: .success((
                statusCode: 200,
                data: Data("{\"address\": \"\(endpointA)\"}".utf8)
            ))
        ]
        defer { DiscoveryURLProtocol.responses = [:] }

        let relaySocket = DiscoveryWebSocketTask(receiveResult: .success(.string("""
        {
          "type": "AGENT_INFO",
          "agent": {
            "address": "\(endpointA)",
            "online": false
          }
        }
        """)))

        let direct = HostedAgentDiscovery(
            session: session,
            relayURL: "wss://relay.test",
            localEndpoints: ["http://local.test"]
        )
        let relay = HostedAgentDiscovery(
            session: session,
            relayURL: "wss://relay.test",
            localEndpoints: [],
            socketFactory: { _ in relaySocket }
        )

        let directAvailability = await direct.checkAvailability(agentAddress: endpointA)
        let relayAvailability = await relay.checkAvailability(agentAddress: endpointA)
        XCTAssertEqual(directAvailability, .online)
        XCTAssertEqual(relayAvailability, .offline)
    }

    func testAgentAvailabilityDecodesLiveRelayLookupShape() async throws {
        let liveAddress = "0xa4c618db1307c03906d37839ea3f278a14856f002817c4466ce286901ef3bb53"
        let socket = DiscoveryWebSocketTask(receiveResult: .success(.string("""
        {
          "type": "AGENT_INFO",
          "agent": {
            "address": "\(liveAddress)",
            "summary": "Code Agent",
            "endpoints": ["http://localhost:8011", "ws://localhost:8011/ws"],
            "last_announce": "2026-08-07T08:34:51.414048",
            "online": true
          }
        }
        """)))
        let discovery = HostedAgentDiscovery(
            session: .shared,
            relayURL: "wss://oo.openonion.ai",
            localEndpoints: [],
            socketFactory: { _ in socket }
        )

        let availability = await discovery.checkAvailability(agentAddress: liveAddress)

        XCTAssertEqual(availability, .online)
        let sentMessages = await socket.recorder.sentMessages
        guard case .string(let requestText) = try XCTUnwrap(sentMessages.first) else {
            return XCTFail("Expected the relay lookup request as text")
        }
        let request = try JSONDecoder().decode(
            [String: String].self,
            from: try XCTUnwrap(requestText.data(using: .utf8))
        )
        XCTAssertEqual(request, ["type": "GET_AGENT", "address": liveAddress])
    }

    func testAgentAvailabilityKeepsUnknownSeparateFromOffline() async {
        let socket = DiscoveryWebSocketTask(
            receiveResult: .failure(URLError(.timedOut))
        )

        let discovery = HostedAgentDiscovery(
            session: .shared,
            relayURL: "wss://relay.test",
            localEndpoints: [],
            socketFactory: { _ in socket }
        )

        let availability = await discovery.checkAvailability(agentAddress: endpointA)
        XCTAssertEqual(availability, .unknown)
    }
}
