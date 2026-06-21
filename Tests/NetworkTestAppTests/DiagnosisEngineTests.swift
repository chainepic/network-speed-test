import Testing
@testable import NetworkTestApp

struct DiagnosisEngineTests {
    @Test func offlinePathReportsProblem() {
        let summary = DiagnosisEngine().summarize(
            ipInfo: nil,
            path: NetworkPathSnapshot(
                status: "Offline",
                interfaces: [],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: false,
                supportsIPv6: false,
                supportsDNS: false,
                likelyUsesVPN: false
            ),
            speed: nil,
            regions: []
        )

        #expect(summary.severity == .problem)
        #expect(summary.findings.contains { $0.id == "offline" })
        #expect(summary.recommendations.contains { $0.id == "check-network-settings" })
    }

    @Test func healthySpeedReportsGood() {
        let summary = DiagnosisEngine().summarize(
            ipInfo: nil,
            path: NetworkPathSnapshot(
                status: "Online",
                interfaces: ["Wi-Fi"],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: true,
                supportsIPv6: true,
                supportsDNS: true,
                likelyUsesVPN: false
            ),
            speed: SpeedTestResult(
                downloadMbps: 100,
                uploadMbps: 20,
                latencyMilliseconds: 40,
                jitterMilliseconds: 5,
                samples: [100],
                endpointName: "Test",
                completedAt: .now,
                errorMessage: nil
            ),
            regions: [
                RegionProbeResult(
                    regionCode: "US",
                    displayName: "US",
                    endpointHost: "example.com",
                    latencyMilliseconds: 80,
                    downloadMbps: 20,
                    isReachable: true,
                    errorMessage: nil
                )
            ]
        )

        #expect(summary.severity == .good)
        #expect(summary.findings.contains { $0.id == "healthy" })
        #expect(summary.recommendations.contains { $0.id == "rerun-diagnostics" })
    }

    @Test func weakLocalNetworkReportsActionableFindings() {
        let summary = DiagnosisEngine().summarize(
            ipInfo: nil,
            path: NetworkPathSnapshot(
                status: "Online",
                interfaces: ["Wi-Fi"],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: true,
                supportsIPv6: false,
                supportsDNS: true,
                likelyUsesVPN: false
            ),
            speed: SpeedTestResult(
                downloadMbps: 3,
                uploadMbps: 0.2,
                latencyMilliseconds: 450,
                jitterMilliseconds: 300,
                samples: [3],
                endpointName: "Test",
                completedAt: .now,
                errorMessage: nil
            ),
            regions: []
        )

        #expect(summary.severity == .problem)
        #expect(summary.findings.contains { $0.id == "download-slow" })
        #expect(summary.findings.contains { $0.id == "upload-slow" })
        #expect(summary.findings.contains { $0.id == "latency-high" })
        #expect(summary.recommendations.contains { $0.id == "move-closer-router" })
    }

    @Test func vpnRoutingProblemSuggestsVpnComparison() {
        let summary = DiagnosisEngine().summarize(
            ipInfo: IPInfo(
                ipAddress: "74.211.106.65",
                city: "Los Angeles",
                region: "California",
                country: "United States",
                isp: "IT7 Networks Inc",
                organization: nil,
                timezone: "America/Los_Angeles",
                source: "test"
            ),
            path: NetworkPathSnapshot(
                status: "Online",
                interfaces: ["Wi-Fi", "Other"],
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: true,
                supportsIPv6: false,
                supportsDNS: true,
                likelyUsesVPN: true
            ),
            speed: SpeedTestResult(
                downloadMbps: 30,
                uploadMbps: 0.9,
                latencyMilliseconds: 364,
                jitterMilliseconds: 201,
                samples: [30],
                endpointName: "Test",
                completedAt: .now,
                errorMessage: nil
            ),
            regions: [
                RegionProbeResult(
                    regionCode: "US-WEST",
                    displayName: "US West",
                    endpointHost: "example.com",
                    latencyMilliseconds: nil,
                    downloadMbps: nil,
                    isReachable: false,
                    errorMessage: "failed"
                )
            ]
        )

        #expect(summary.severity == .warning)
        #expect(summary.findings.contains { $0.id == "vpn-detected" })
        #expect(summary.recommendations.contains { $0.id == "compare-vpn-off" })
    }

    @Test func productionSafePolicyKeepsMeteredTestsProfitable() {
        let policy = CostProtectionPolicy.productionSafe

        for profile in policy.profiles {
            #expect(policy.isProfitProtected(profile))
            if profile.creditsRequired > 0 {
                let marginRate = profile.grossMarginRate(
                    perTerabyteUSD: policy.worstCaseEgressCostPerTerabyteUSD,
                    usdToRMB: policy.usdToRMB,
                    perCreditRMB: policy.netRevenuePerCreditRMB
                )
                #expect((marginRate ?? 0) >= 0.8)
            }
        }
    }
}
