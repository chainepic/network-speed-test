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
                title: "重新检测网络",
                details: "刷新公网 IP、系统网络路径、测速和全球节点结果，用来确认问题是否已经恢复。"
            ),
            RepairAction(
                id: "check-network-settings",
                title: "检查系统网络设置",
                details: "进入系统网络设置，检查 Wi-Fi、低数据模式、代理、VPN 和 DNS 配置。"
            )
        ]

        guard path.status == "Online" else {
            return DiagnosisSummary(
                title: "当前网络不可用",
                details: "系统报告没有可用网络连接，请先检查 Wi-Fi、蜂窝网络或路由器状态。",
                severity: .problem,
                findings: [
                    DiagnosticFinding(
                        id: "offline",
                        title: "系统网络处于离线状态",
                        details: "Network.framework 没有发现可用路径，测速和区域探测结果暂时无法代表真实网络质量。",
                        impact: "网页、聊天、会议和 VPN 都可能无法连接。",
                        severity: .problem
                    )
                ],
                recommendations: recommendations + [
                    RepairAction(
                        id: "check-router",
                        title: "检查路由器和物理连接",
                        details: "确认 Wi-Fi 已连接、路由器可以访问互联网，必要时重启路由器后再测一次。"
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
                    title: "DNS 能力异常",
                    details: "系统网络路径没有报告 DNS 支持，可能存在 DNS 配置、代理或网络策略问题。",
                    impact: "App 可能显示“无网络”，但直接访问 IP 或部分连接仍然可用。",
                    severity: .problem
                )
            )
            recommendations.append(
                RepairAction(
                    id: "reset-dns",
                    title: "检查 DNS 设置",
                    details: "在系统网络设置中切换为自动 DNS，或临时改用可信 DNS 后重新测试。"
                )
            )
        }

        if path.isConstrained || path.isExpensive {
            findings.append(
                DiagnosticFinding(
                    id: "system-policy-limited",
                    title: "系统网络策略可能限速",
                    details: "当前网络被系统标记为受限或昂贵网络，常见于低数据模式、热点或蜂窝网络。",
                    impact: "下载、后台同步、视频和云盘上传可能被系统主动压低。",
                    severity: .warning
                )
            )
            recommendations.append(
                RepairAction(
                    id: "disable-low-data-mode",
                    title: "关闭低数据模式或切换网络",
                    details: "如果正在使用热点、蜂窝网络或低数据模式，切换到稳定 Wi-Fi 后再诊断。"
                )
            )
        }

        if download > 0, download < 10 {
            findings.append(
                DiagnosticFinding(
                    id: "download-slow",
                    title: "下载速度偏低",
                    details: "本次下载只有 \(download.formattedMbps)，低于日常高清视频和大文件下载的舒适范围。",
                    impact: "网页图片、视频缓冲、系统更新和下载任务会明显变慢。",
                    severity: .problem
                )
            )
        }

        if upload > 0, upload < 2 {
            findings.append(
                DiagnosticFinding(
                    id: "upload-slow",
                    title: "上传速度偏低",
                    details: "本次上传只有 \(upload.formattedMbps)，视频会议、网盘同步和远程办公会受到影响。",
                    impact: "摄像头画面、语音稳定性、文件上传和远程桌面可能卡顿。",
                    severity: .problem
                )
            )
        }

        if latency > 250 {
            findings.append(
                DiagnosticFinding(
                    id: "latency-high",
                    title: "基础延迟过高",
                    details: "当前基础延迟约 \(latency.formattedMilliseconds)，已经超过实时交互的舒适范围。",
                    impact: "游戏、会议、远程控制和网页首屏加载会感觉迟钝。",
                    severity: .warning
                )
            )
        }

        if jitter > 120 {
            findings.append(
                DiagnosticFinding(
                    id: "jitter-high",
                    title: "网络抖动过大",
                    details: "延迟波动约 \(jitter.formattedMilliseconds)，说明连接稳定性不足。",
                    impact: "语音、视频会议和游戏可能出现忽快忽慢、断续或掉线。",
                    severity: .warning
                )
            )
        }

        if regions.isEmpty == false, reachableRatio < 0.6 {
            findings.append(
                DiagnosticFinding(
                    id: "regions-unreachable",
                    title: "多个区域节点不可达或延迟异常",
                    details: "全球节点可达率约 \(reachableRatio.formattedPercent)，跨区域访问质量不稳定。",
                    impact: "海外网站、跨区游戏、远程服务或 VPN 分流线路可能体验较差。",
                    severity: .warning
                )
            )
        }

        if vpnHint {
            findings.append(
                DiagnosticFinding(
                    id: "vpn-detected",
                    title: "检测到 VPN 或隧道接口",
                    details: ipInfo?.locationDescription.isEmpty == false
                        ? "当前公网位置显示为 \(ipInfo?.locationDescription ?? "未知")，系统也检测到隧道接口。"
                        : "系统检测到 utun/tun/tap/ppp 等隧道接口。",
                    impact: "测速结果可能主要反映 VPN 节点、跨境路由和分流策略，而不是本地宽带上限。",
                    severity: .warning
                )
            )
            recommendations.append(
                RepairAction(
                    id: "compare-vpn-off",
                    title: "关闭 VPN 后再测一次",
                    details: "如果关闭 VPN 后结果明显变好，问题更可能来自 VPN 节点或线路；如果仍然很慢，更可能是本地网络。"
                )
            )
        }

        if download > 50, upload > 5, latency < 120, reachableRatio > 0.75 {
            return DiagnosisSummary(
                title: vpnHint ? "网络整体正常，VPN 当前可用" : "网络整体正常",
                details: "本机连接、基础测速和多数区域节点表现正常。如果某个 App 仍然慢，更可能是目标服务或单一路由问题。",
                severity: .good,
                findings: findings.isEmpty ? [
                    DiagnosticFinding(
                        id: "healthy",
                        title: "核心指标正常",
                        details: "下载、上传、延迟和区域可达性都处在可用范围内。",
                        impact: "日常浏览、视频、下载和会议通常不会受到本机网络限制。",
                        severity: .good
                    )
                ] : findings,
                recommendations: recommendations
            )
        }

        if vpnHint, reachableRatio < 0.6 {
            return DiagnosisSummary(
                title: "更像 VPN 或跨境路由问题",
                details: "检测到 VPN 接口迹象，同时多个海外/区域端点不可达或延迟过高。建议临时关闭 VPN 重新测试，比较 IP 和区域结果。",
                severity: .warning,
                findings: findings,
                recommendations: recommendations
            )
        }

        if download < 10, upload < 2, latency > 250 {
            return DiagnosisSummary(
                title: "更像本地网络质量问题",
                details: "下载、上传和基础延迟都偏弱。建议靠近路由器、切换网络，或用同一网络下另一台设备交叉验证。",
                severity: .problem,
                findings: findings,
                recommendations: recommendations + [
                    RepairAction(
                        id: "move-closer-router",
                        title: "靠近路由器或切换 Wi-Fi",
                        details: "同一位置用手机热点或另一台设备交叉验证，确认是否为当前 Wi-Fi 或路由器问题。"
                    )
                ]
            )
        }

        if let ipInfo, ipInfo.locationDescription.isEmpty == false, vpnHint {
            return DiagnosisSummary(
                title: "检测到 VPN 线索",
                details: "当前公网 IP 显示为 \(ipInfo.locationDescription)，且系统接口存在 VPN 迹象。可关闭 VPN 再测一次来确认瓶颈来源。",
                severity: .warning,
                findings: findings,
                recommendations: recommendations
            )
        }

        return DiagnosisSummary(
            title: "结果需要对比确认",
            details: "当前结果没有明显单一瓶颈。建议分别在 VPN 开启和关闭时各运行一次，比较公网 IP、基础测速和区域节点延迟。",
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
