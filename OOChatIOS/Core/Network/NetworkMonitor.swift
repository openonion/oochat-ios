import Network

protocol NetworkPathMonitoring: AnyObject {
    var onUpdate: (@MainActor (Bool) -> Void)? { get set }
    func start()
    func cancel()
}

final class NetworkMonitor: NetworkPathMonitoring {
    var onUpdate: (@MainActor (Bool) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "connectonion.native-ios.network-monitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            // Bind self before the Task rather than writing `self?.onUpdate` inside
            // it. Under Swift 5 concurrency checking, the optional from [weak self]
            // is a mutable capture, and reading it from a concurrently-executing
            // closure is an error. The guard turns it into an immutable `let`, and
            // the strong reference lives only as long as this hop to the main actor.
            guard let self else { return }
            Task { @MainActor in
                self.onUpdate?(isOnline)
            }
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}
