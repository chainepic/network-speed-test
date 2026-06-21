import Foundation

protocol SpeedTestServicing: Sendable {
    func runSpeedTest(profile: MeteredTestProfile?) async -> SpeedTestResult
}

extension SpeedTestServicing {
    func runSpeedTest() async -> SpeedTestResult {
        await runSpeedTest(profile: nil)
    }
}

struct SpeedTestService: SpeedTestServicing {
    var downloadEndpoints: [TestEndpoint] = EndpointCatalog.download
    var uploadEndpoints: [TestEndpoint] = EndpointCatalog.upload
    var session: URLSession = .shared

    func runSpeedTest(profile: MeteredTestProfile? = nil) async -> SpeedTestResult {
        let startedAt = Date()
        var samples: [Double] = []
        var downloadMbps: Double?
        var uploadMbps: Double?
        var latency: Double?
        var jitter: Double?
        var endpointName = "No endpoint"
        var errorMessages: [String] = []
        var downloadEndpointName: String?
        var uploadEndpointName: String?
        let activeDownloadEndpoints = downloadEndpoints(for: profile)
        let activeUploadEndpoints = uploadEndpoints(for: profile)

        if let endpoint = activeDownloadEndpoints.first {
            downloadEndpointName = endpoint.name
            endpointName = endpoint.name
            do {
                let latencySamples = try await latencySamples(for: endpoint.url, count: 4)
                latency = latencySamples.average
                jitter = latencySamples.jitter
                let download = try await measureDownload(endpoint: endpoint)
                samples.append(download)
                downloadMbps = download
            } catch {
                errorMessages.append("Download: \(error.localizedDescription)")
            }
        }

        var uploadErrors: [String] = []
        for endpoint in activeUploadEndpoints {
            do {
                uploadMbps = try await measureUpload(endpoint: endpoint)
                uploadEndpointName = endpoint.name
                break
            } catch {
                uploadErrors.append("\(endpoint.name): \(error.localizedDescription)")
            }
        }
        if uploadMbps == nil, uploadErrors.isEmpty == false {
            errorMessages.append("Upload: \(uploadErrors.joined(separator: " / "))")
        }

        endpointName = endpointDescription(download: downloadEndpointName, upload: uploadEndpointName)

        return SpeedTestResult(
            downloadMbps: downloadMbps,
            uploadMbps: uploadMbps,
            latencyMilliseconds: latency,
            jitterMilliseconds: jitter,
            samples: samples,
            endpointName: endpointName,
            completedAt: startedAt,
            errorMessage: errorMessages.isEmpty ? nil : errorMessages.joined(separator: "\n")
        )
    }

    private func downloadEndpoints(for profile: MeteredTestProfile?) -> [TestEndpoint] {
        guard let profile else { return downloadEndpoints }
        let bytes = Int(profile.downloadMegabytes * 1_000_000)
        return [
            TestEndpoint(
                id: "\(profile.id)-download",
                name: "\(profile.name) / Cloudflare",
                regionCode: nil,
                url: URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)")!,
                kind: .download(bytes: bytes)
            )
        ]
    }

    private func uploadEndpoints(for profile: MeteredTestProfile?) -> [TestEndpoint] {
        guard let profile else { return uploadEndpoints }
        let bytes = Int(profile.uploadIngressMegabytes * 1_000_000)
        guard bytes > 0 else { return [] }
        return uploadEndpoints.map { endpoint in
            TestEndpoint(
                id: "\(profile.id)-\(endpoint.id)",
                name: "\(profile.name) / \(endpoint.name)",
                regionCode: endpoint.regionCode,
                url: endpoint.url,
                kind: .upload(bytes: bytes)
            )
        }
    }

    private func endpointDescription(download: String?, upload: String?) -> String {
        switch (download, upload) {
        case let (download?, upload?):
            "下载：\(download) / 上传：\(upload)"
        case let (download?, nil):
            "下载：\(download) / 上传：失败"
        case let (nil, upload?):
            "下载：失败 / 上传：\(upload)"
        case (nil, nil):
            "No endpoint"
        }
    }

    private func latencySamples(for url: URL, count: Int) async throws -> [Double] {
        var samples: [Double] = []
        for _ in 0..<count {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 6
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let start = Date()
            _ = try await session.data(for: request)
            samples.append(Date().timeIntervalSince(start) * 1_000)
        }
        return samples
    }

    private func measureDownload(endpoint: TestEndpoint) async throws -> Double {
        var request = URLRequest(url: endpoint.url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let start = Date()
        let (data, response) = try await session.data(for: request)
        try validate(response)

        let seconds = max(Date().timeIntervalSince(start), 0.001)
        return megabitsPerSecond(bytes: data.count, seconds: seconds)
    }

    private func measureUpload(endpoint: TestEndpoint) async throws -> Double {
        let byteCount: Int
        if case let .upload(bytes) = endpoint.kind {
            byteCount = bytes
        } else {
            byteCount = 1_000_000
        }

        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let payload = Data(repeating: 0x61, count: byteCount)
        let start = Date()
        let (_, response) = try await session.upload(for: request, from: payload)
        try validate(response)

        let seconds = max(Date().timeIntervalSince(start), 0.001)
        return megabitsPerSecond(bytes: byteCount, seconds: seconds)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<500).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func megabitsPerSecond(bytes: Int, seconds: TimeInterval) -> Double {
        (Double(bytes) * 8 / 1_000_000) / seconds
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard isEmpty == false else { return nil }
        return reduce(0, +) / Double(count)
    }

    var jitter: Double? {
        guard count > 1 else { return nil }
        let deltas = zip(self, dropFirst()).map { abs($0 - $1) }
        return deltas.reduce(0, +) / Double(deltas.count)
    }
}
