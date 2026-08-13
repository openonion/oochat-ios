import Combine
import Foundation

@MainActor
final class AgentPresenceCoordinator: ObservableObject {
    @Published private var availabilityByAddress: [String: AgentAvailability] = [:]

    private(set) var pollingTask: Task<Void, Never>?
    var pollingInterval: TimeInterval = 15 {
        didSet {
            pollingInterval = max(0.1, pollingInterval)
        }
    }

    private let availabilityChecker: AgentAvailabilityChecking
    private let agentAddresses: () -> [String]
    private var generation = 0
    private var isForeground = true
    private var isNetworkAvailable = false

    init(
        availabilityChecker: AgentAvailabilityChecking,
        agentAddresses: @escaping () -> [String]
    ) {
        self.availabilityChecker = availabilityChecker
        self.agentAddresses = agentAddresses
    }

    deinit {
        pollingTask?.cancel()
    }

    func isOnline(address: String) -> Bool {
        availabilityByAddress[address] == .online
    }

    func networkAvailabilityDidChange(isOnline: Bool) {
        isNetworkAvailable = isOnline
        guard isOnline else {
            cancelPolling()
            availabilityByAddress.removeAll()
            return
        }
        startPollingIfPossible()
    }

    func applicationDidBecomeInactive() {
        isForeground = false
        cancelPolling()
    }

    func applicationDidBecomeActive() {
        isForeground = true
        startPollingIfPossible()
    }

    func agentsDidChange() {
        pruneAvailability()
        startPollingIfPossible()
    }

    private func startPollingIfPossible() {
        pollingTask?.cancel()
        generation += 1
        let currentGeneration = generation
        pruneAvailability()

        guard isNetworkAvailable, isForeground, !currentAddresses.isEmpty else {
            pollingTask = nil
            return
        }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard await self?.refresh(generation: currentGeneration) == true,
                      let interval = self?.pollingInterval else {
                    return
                }
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    private func refresh(generation currentGeneration: Int) async -> Bool {
        guard currentGeneration == generation, isNetworkAvailable, isForeground else {
            return false
        }

        pruneAvailability()
        for address in currentAddresses {
            guard !Task.isCancelled,
                  currentGeneration == generation,
                  isNetworkAvailable,
                  isForeground else {
                return false
            }
            let availability = await availabilityChecker.checkAgentAvailability(
                agentAddress: address
            )
            guard !Task.isCancelled, currentGeneration == generation else {
                return false
            }
            if availability != .unknown {
                availabilityByAddress[address] = availability
            }
        }
        return true
    }

    private var currentAddresses: [String] {
        var seen: Set<String> = []
        return agentAddresses().filter { seen.insert($0).inserted }
    }

    private func pruneAvailability() {
        let addresses = Set(currentAddresses)
        availabilityByAddress = availabilityByAddress.filter { addresses.contains($0.key) }
    }

    private func cancelPolling() {
        generation += 1
        pollingTask?.cancel()
        pollingTask = nil
    }
}
