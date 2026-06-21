import Foundation
import Network

protocol NetworkPathServicing: Sendable {
    func currentSnapshot() async -> NetworkPathSnapshot
}

struct NetworkPathService: NetworkPathServicing {
    func currentSnapshot() async -> NetworkPathSnapshot {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "networktest.path.monitor")

            monitor.pathUpdateHandler = { path in
                let snapshot = NetworkPathSnapshot(
                    status: path.status.displayName,
                    interfaces: Self.interfaceNames(for: path),
                    isExpensive: path.isExpensive,
                    isConstrained: path.isConstrained,
                    supportsIPv4: path.supportsIPv4,
                    supportsIPv6: path.supportsIPv6,
                    supportsDNS: path.supportsDNS,
                    likelyUsesVPN: Self.detectsVPNInterface()
                )
                continuation.resume(returning: snapshot)
                monitor.cancel()
            }

            monitor.start(queue: queue)
        }
    }

    private static func interfaceNames(for path: NWPath) -> [String] {
        let candidates: [(NWInterface.InterfaceType, String)] = [
            (.wifi, "Wi-Fi"),
            (.cellular, "Cellular"),
            (.wiredEthernet, "Ethernet"),
            (.loopback, "Loopback"),
            (.other, "Other")
        ]

        return candidates
            .filter { path.usesInterfaceType($0.0) }
            .map(\.1)
    }

    private static func detectsVPNInterface() -> Bool {
        var interfacesPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacesPointer) == 0, let first = interfacesPointer else {
            return false
        }
        defer { freeifaddrs(interfacesPointer) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let name = String(cString: current.pointee.ifa_name)
            if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("tap") || name.hasPrefix("ppp") {
                return true
            }
            pointer = current.pointee.ifa_next
        }

        return false
    }
}

private extension NWPath.Status {
    var displayName: String {
        switch self {
        case .satisfied:
            "Online"
        case .unsatisfied:
            "Offline"
        case .requiresConnection:
            "Requires Connection"
        @unknown default:
            "Unknown"
        }
    }
}
