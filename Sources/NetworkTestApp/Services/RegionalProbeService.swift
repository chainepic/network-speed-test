import Foundation

protocol RegionalProbeServicing: Sendable {
    func probeRegions(includePremium: Bool) async -> [RegionProbeResult]
}

extension RegionalProbeServicing {
    func probeRegions() async -> [RegionProbeResult] {
        await probeRegions(includePremium: false)
    }
}

struct RegionalProbeService: RegionalProbeServicing {
    var endpoints: [TestEndpoint] = EndpointCatalog.regional
    var session: URLSession = .shared

    func probeRegions(includePremium: Bool = false) async -> [RegionProbeResult] {
        let activeEndpoints = includePremium ? endpoints : endpoints.filter { $0.requiresMembership == false }

        return await withTaskGroup(of: RegionProbeResult.self) { group in
            for endpoint in activeEndpoints {
                group.addTask {
                    await probe(endpoint)
                }
            }

            var results: [RegionProbeResult] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.displayName < $1.displayName }
        }
    }

    private func probe(_ endpoint: TestEndpoint) async -> RegionProbeResult {
        do {
            let latency = try await measureLatency(endpoint.url)
            let throughput = try? await measureSmallDownload(endpoint.url)
            return RegionProbeResult(
                regionCode: endpoint.regionCode ?? endpoint.id,
                displayName: endpoint.name,
                endpointHost: endpoint.url.host() ?? endpoint.url.absoluteString,
                latencyMilliseconds: latency,
                downloadMbps: throughput,
                isReachable: true,
                errorMessage: nil,
                requiresMembership: endpoint.requiresMembership
            )
        } catch {
            return RegionProbeResult(
                regionCode: endpoint.regionCode ?? endpoint.id,
                displayName: endpoint.name,
                endpointHost: endpoint.url.host() ?? endpoint.url.absoluteString,
                latencyMilliseconds: nil,
                downloadMbps: nil,
                isReachable: false,
                errorMessage: error.localizedDescription,
                requiresMembership: endpoint.requiresMembership
            )
        }
    }

    private func measureLatency(_ url: URL) async throws -> Double {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let start = Date()
        let (_, response) = try await session.data(for: request)
        try validate(response)
        return Date().timeIntervalSince(start) * 1_000
    }

    private func measureSmallDownload(_ url: URL) async throws -> Double {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("bytes=0-262143", forHTTPHeaderField: "Range")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let start = Date()
        let (data, response) = try await session.data(for: request)
        try validate(response)

        guard data.count >= 8_192 else {
            throw URLError(.zeroByteResource)
        }

        let seconds = max(Date().timeIntervalSince(start), 0.001)
        return (Double(data.count) * 8 / 1_000_000) / seconds
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<500).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
