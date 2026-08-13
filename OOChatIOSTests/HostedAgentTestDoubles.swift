@testable import OOChatIOS

actor PromptGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

final class MockNetworkMonitor: NetworkPathMonitoring {
    var onUpdate: (@MainActor (Bool) -> Void)?
    private(set) var started = false
    private(set) var cancelled = false

    func start() {
        started = true
    }

    func cancel() {
        cancelled = true
    }

    @MainActor
    func simulate(online: Bool) {
        onUpdate?(online)
    }
}

final class MockAgentTransport: HostedAgentTransport {
    enum Behavior {
        case succeed(output: String)
        case fail(Error)
        case wait(gate: PromptGate, output: String)
        case waitThenFail(gate: PromptGate, error: Error)
        case waitUntilCancelled
    }

    var connectBehavior: Behavior = .succeed(output: "")
    var sendBehavior: Behavior = .succeed(output: "mock reply")
    var onConnectionStateChange: (@MainActor (String, ConversationConnectionState) -> Void)?
    var sendBehaviorsByPrompt: [String: Behavior] = [:]
    var streamedEvents: [HostedAgentEvent] = []
    var approvalRequests: [ToolApprovalRequest] = []
    var ulwCheckpoints: [UlwCheckpointRequest] = []
    var planReviews: [PlanReviewRequest] = []
    var askUserRequests: [AskUserRequest] = []
    var availableSkills: [AgentSkill] = []
    var skillsByAddress: [String: [AgentSkill]] = [:]
    var agentNamesByAddress: [String: String] = [:]
    var agentAvailabilityByAddress: [String: AgentAvailability] = [:]
    var defaultAgentAvailability: AgentAvailability = .unknown
    var skillFetchError: Error?
    var onSend: (@MainActor () -> Void)?
    var waitAfterInteractionsUntilCancelled = false

    private(set) var networkLossNotices = 0
    private(set) var connectedAddresses: [String] = []
    private(set) var sentPrompts: [String] = []
    private(set) var sentImages: [[String]] = []
    private(set) var sentFiles: [[HostedAgentFilePayload]] = []
    private(set) var approvalDecisions: [ApprovalDecision] = []
    private(set) var ulwDecisions: [UlwCheckpointDecision] = []
    private(set) var planReviewDecisions: [PlanReviewDecision] = []
    private(set) var askUserDecisions: [AskUserDecision] = []
    private(set) var fetchedSkillAddresses: [String] = []
    private(set) var fetchedNameAddresses: [String] = []
    private(set) var checkedAvailabilityAddresses: [String] = []
    private(set) var interactionResponseWaits: [(agentAddress: String, conversationID: String)] = []

    func connect(agentAddress: String, conversation: Conversation) async throws -> HostedAgentResult {
        connectedAddresses.append(agentAddress)
        switch connectBehavior {
        case .succeed:
            return HostedAgentResult(
                output: nil,
                endpointLabel: "mock",
                serverSession: ["session_id": .string(conversation.id)]
            )
        case .fail(let error):
            throw error
        case .wait(let gate, _):
            await gate.wait()
            return HostedAgentResult(
                output: nil,
                endpointLabel: "mock",
                serverSession: ["session_id": .string(conversation.id)]
            )
        case .waitThenFail(let gate, let error):
            await gate.wait()
            throw error
        case .waitUntilCancelled:
            while true {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    func fetchSkills(agentAddress: String) async throws -> [AgentSkill] {
        fetchedSkillAddresses.append(agentAddress)
        if let skillFetchError {
            throw skillFetchError
        }
        return skillsByAddress[agentAddress] ?? availableSkills
    }

    func fetchAgentName(agentAddress: String) async throws -> String? {
        fetchedNameAddresses.append(agentAddress)
        return agentNamesByAddress[agentAddress]
    }

    func checkAgentAvailability(agentAddress: String) async -> AgentAvailability {
        checkedAvailabilityAddresses.append(agentAddress)
        return agentAvailabilityByAddress[agentAddress] ?? defaultAgentAvailability
    }

    func sendPrompt(
        agentAddress: String,
        conversation: Conversation,
        prompt: HostedAgentPrompt,
        onEvent: (@MainActor (HostedAgentEvent) -> Void)?,
        onInteraction: (@MainActor (HostedAgentInteraction) async -> HostedAgentInteractionDecision)?
    ) async throws -> HostedAgentResult {
        sentPrompts.append(prompt.text)
        sentImages.append(prompt.images)
        sentFiles.append(prompt.files)
        let output = try await output(for: sendBehaviorsByPrompt[prompt.text] ?? sendBehavior)
        try await replayInteractions(onInteraction: onInteraction)
        if waitAfterInteractionsUntilCancelled {
            while true {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        for event in streamedEvents {
            await onEvent?(event)
        }
        if let onSend {
            await MainActor.run { onSend() }
        }
        return HostedAgentResult(output: output, endpointLabel: "mock", serverSession: nil)
    }

    private func output(for behavior: Behavior) async throws -> String {
        switch behavior {
        case .succeed(let value):
            return value
        case .fail(let error):
            throw error
        case .wait(let gate, let value):
            await gate.wait()
            try Task.checkCancellation()
            return value
        case .waitThenFail(let gate, let error):
            await gate.wait()
            throw error
        case .waitUntilCancelled:
            while true {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    private func replayInteractions(
        onInteraction: (@MainActor (HostedAgentInteraction) async -> HostedAgentInteractionDecision)?
    ) async throws {
        for request in approvalRequests {
            guard let onInteraction,
                  case .approval(let decision) = await onInteraction(.approval(request)) else {
                throw HostedAgentClientError.badFrame
            }
            approvalDecisions.append(decision)
        }
        for checkpoint in ulwCheckpoints {
            guard let onInteraction,
                  case .ulwCheckpoint(let decision) = await onInteraction(.ulwCheckpoint(checkpoint)) else {
                throw HostedAgentClientError.badFrame
            }
            ulwDecisions.append(decision)
        }
        for review in planReviews {
            guard let onInteraction,
                  case .planReview(let decision) = await onInteraction(.planReview(review)) else {
                throw HostedAgentClientError.badFrame
            }
            planReviewDecisions.append(decision)
        }
        for request in askUserRequests {
            guard let onInteraction,
                  case .askUser(let decision) = await onInteraction(.askUser(request)) else {
                throw HostedAgentClientError.badFrame
            }
            askUserDecisions.append(decision)
        }
    }

    func noteNetworkLost() async {
        networkLossNotices += 1
    }

    func waitForPendingInteractionResponses(agentAddress: String, conversationID: String) async {
        interactionResponseWaits.append((agentAddress, conversationID))
        for _ in 0..<100 where approvalDecisions.isEmpty
            && ulwDecisions.isEmpty
            && planReviewDecisions.isEmpty
            && askUserDecisions.isEmpty {
            await Task.yield()
        }
    }

    var askUserAnswers: [String] {
        askUserDecisions.compactMap { decision in
            guard case .answer(let answer) = decision else {
                return nil
            }
            return answer
        }
    }

    @MainActor
    func simulateConnectionState(_ state: ConversationConnectionState, conversationID: String) {
        onConnectionStateChange?(conversationID, state)
    }
}
