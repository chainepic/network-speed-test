import Foundation

struct DiagnosisEngine: Sendable {
    func summarize(
        ipInfo: IPInfo?,
        path: NetworkPathSnapshot,
        speed: SpeedTestResult?,
        regions: [RegionProbeResult]
    ) -> DiagnosisSummary {
        var findings: [DiagnosticFinding] = []
        var recommendations: [RepairAction] = [
            RepairAction(
                id: "rerun-diagnostics",
                title: "Run diagnostics again",
                details: "Refresh public IP, network path, speed test, and global node results to confirm whether the issue has cleared."
            ),
            RepairAction(
                id: "check-network-settings",
                title: "Check system network settings",
                details: "Review Wi-Fi, Low Data Mode, proxy, VPN, and DNS settings in System Settings."
            )
        ]

        guard path.status == "Online" else {
            return DiagnosisSummary(
                title: "Network is unavailable",
                details: "The system reports no active network connection. Check Wi-Fi, cellular service, or your router first.",
                severity: .problem,
                findings: [
                    DiagnosticFinding(
                        id: "offline",
                        title: "System network is offline",
                        details: "Network.framework did not find an active path, so speed and regional results may not reflect real network quality.",
                        impact: "Websites, chat, meetings, and VPN connections may all fail.",
                        severity: .problem
                    )
                ],
                recommendations: recommendations + [
                    RepairAction(
                        id: "check-router",
                        title: "Check router and physical connection",
                        details: "Confirm Wi-Fi is connected, the router has internet access, and restart the router if needed before testing again."
                    )
                ]
            )
        }

        let download = speed?.downloadMbps ?? 0
        let upload = speed?.uploadMbps ?? 0
        let latency = speed?.latencyMilliseconds ?? 0
        let jitter = speed?.jitterMilliseconds ?? 0
        let reachableRatio = reachableRatio(regions)
        let vpnHint = path.likelyUsesVPN

        if path.supportsDNS == false {
            findings.append(
                DiagnosticFinding(
                    id: "dns-unavailable",
                    title: "DNS capability looks abnormal",
                    details: "The active network path does not report DNS support, which may indicate DNS, proxy, or policy issues.",
                    impact: "Apps may show no network even though some IP-based connections still work.",
                    severity: .problem
                )
            )
            recommendations.append(
                RepairAction(
                    id: "reset-dns",
                    title: "Check DNS settings",
                    details: "Switch to automatic DNS in System Settings, or temporarily use a trusted DNS provider and test again."
                )
            )
        }

        if path.isConstrained || path.isExpensive {
            findings.append(
                DiagnosticFinding(
                    id: "system-policy-limited",
                    title: "System network policy may be limiting traffic",
                    details: "The current network is marked as constrained or expensive, which is common on hotspots, cellular, or Low Data Mode.",
                    impact: "Downloads, background sync, video, and cloud uploads may be throttled by the system.",
                    severity: .warning
                )
            )
            recommendations.append(
                RepairAction(
                    id: "disable-low-data-mode",
                    title: "Disable Low Data Mode or switch networks",
                    details: "If you are on a hotspot, cellular network, or Low Data Mode, switch to stable Wi-Fi and run diagnostics again."
                )
            )
        }

        if download > 0, download < 10 {
            findings.append(
                DiagnosticFinding(
                    id: "download-slow",
                    title: "Download speed is low",
                    details: "Download measured only \(download.formattedMbps), which is below a comfortable range for HD video and large downloads.",
                    impact: "Web pages, video buffering, system updates, and downloads will feel slow.",
                    severity: .problem
                )
            )
        }

        if upload > 0, upload < 2 {
            findings.append(
                DiagnosticFinding(
                    id: "upload-slow",
                    title: "Upload speed is low",
                    details: "Upload measured only \(upload.formattedMbps), which can affect video calls, cloud sync, and remote work.",
                    impact: "Camera feeds, voice stability, file uploads, and remote desktop may stutter.",
                    severity: .problem
                )
            )
        }

        if latency > 250 {
            findings.append(
                DiagnosticFinding(
                    id: "latency-high",
                    title: "Baseline latency is high",
                    details: "Baseline latency is about \(latency.formattedMilliseconds), which is above a comfortable range for real-time interaction.",
                    impact: "Gaming, meetings, remote control, and page loads will feel sluggish.",
                    severity: .warning
                )
            )
        }

        if jitter > 120 {
            findings.append(
                DiagnosticFinding(
                    id: "jitter-high",
                    title: "Network jitter is high",
                    details: "Latency fluctuation is about \(jitter.formattedMilliseconds), which indicates unstable connectivity.",
                    impact: "Voice, video calls, and games may feel uneven or drop unexpectedly.",
                    severity: .warning
                )
            )
        }

        if regions.isEmpty == false, reachableRatio < 0.6 {
            findings.append(
                DiagnosticFinding(
                    id: "regions-unreachable",
                    title: "Multiple regional nodes are unreachable or slow",
                    details: "Global node reachability is about \(reachableRatio.formattedPercent), so cross-region access looks unstable.",
                    impact: "Overseas sites, cross-region games, remote services, or VPN routes may perform poorly.",
                    severity: .warning
                )
            )
        }

        if vpnHint {
            findings.append(
                DiagnosticFinding(
                    id: "vpn-detected",
                    title: "VPN or tunnel interface detected",
                    details: ipInfo?.locationDescription.isEmpty == false
                        ? "Public IP currently shows \(ipInfo?.locationDescription ?? "Unknown"), and the system also detected tunnel interfaces."
                        : "The system detected utun/tun/tap/ppp tunnel interfaces.",
                    impact: "Speed results may reflect the VPN node, cross-border routing, and split tunneling rather than local ISP capacity.",
                    severity: .warning
                )
            )
            recommendations.append(
                RepairAction(
                    id: "compare-vpn-off",
                    title: "Test again with VPN disabled",
                    details: "If results improve significantly with VPN off, the bottleneck is more likely the VPN route. If they stay slow, local network is more likely."
                )
            )
        }

        if download > 50, upload > 5, latency < 120, reachableRatio > 0.75 {
            return DiagnosisSummary(
                title: vpnHint ? "Network looks healthy with VPN active" : "Network looks healthy",
                details: "Local connectivity, baseline speed, and most regional nodes look normal. If one app is still slow, the target service or a single route is more likely.",
                severity: .good,
                findings: findings.isEmpty ? [
                    DiagnosticFinding(
                        id: "healthy",
                        title: "Core metrics look normal",
                        details: "Download, upload, latency, and regional reachability are within a usable range.",
                        impact: "Everyday browsing, video, downloads, and meetings should not be limited by local network conditions.",
                        severity: .good
                    )
                ] : findings,
                recommendations: recommendations
            )
        }

        if vpnHint, reachableRatio < 0.6 {
            return DiagnosisSummary(
                title: "Likely a VPN or cross-border routing issue",
                details: "VPN interfaces were detected while multiple overseas or regional endpoints are unreachable or slow. Disable VPN temporarily and compare IP and regional results.",
                severity: .warning,
                findings: findings,
                recommendations: recommendations
            )
        }

        if download < 10, upload < 2, latency > 250 {
            return DiagnosisSummary(
                title: "Likely a local network quality issue",
                details: "Download, upload, and baseline latency are all weak. Move closer to the router, switch networks, or cross-check with another device on the same network.",
                severity: .problem,
                findings: findings,
                recommendations: recommendations + [
                    RepairAction(
                        id: "move-closer-router",
                        title: "Move closer to the router or switch Wi-Fi",
                        details: "Cross-check with a phone hotspot or another device in the same location to confirm whether the current Wi-Fi or router is the bottleneck."
                    )
                ]
            )
        }

        if let ipInfo, ipInfo.locationDescription.isEmpty == false, vpnHint {
            return DiagnosisSummary(
                title: "VPN clues detected",
                details: "Public IP currently shows \(ipInfo.locationDescription), and the system interfaces suggest VPN activity. Disable VPN and test again to confirm where the bottleneck is.",
                severity: .warning,
                findings: findings,
                recommendations: recommendations
            )
        }

        return DiagnosisSummary(
            title: "Results need comparison",
            details: "No single bottleneck stands out. Run diagnostics once with VPN enabled and once with VPN disabled, then compare public IP, baseline speed, and regional latency.",
            severity: findings.isEmpty ? .unknown : worstSeverity(in: findings),
            findings: findings,
            recommendations: recommendations
        )
    }

    private func reachableRatio(_ regions: [RegionProbeResult]) -> Double {
        guard regions.isEmpty == false else { return 1 }
        let reachable = regions.filter(\.isReachable).count
        return Double(reachable) / Double(regions.count)
    }

    private func worstSeverity(in findings: [DiagnosticFinding]) -> DiagnosisSeverity {
        if findings.contains(where: { $0.severity == .problem }) {
            return .problem
        }
        if findings.contains(where: { $0.severity == .warning }) {
            return .warning
        }
        if findings.contains(where: { $0.severity == .good }) {
            return .good
        }
        return .unknown
    }
}
