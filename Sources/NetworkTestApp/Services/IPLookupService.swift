import Foundation

protocol IPLookupServicing: Sendable {
    func lookup() async -> IPInfo
}

struct IPLookupService: IPLookupServicing {
    var endpoints: [TestEndpoint] = EndpointCatalog.ipLookup
    var session: URLSession = .shared

    func lookup() async -> IPInfo {
        for endpoint in endpoints {
            do {
                let data = try await fetch(endpoint.url)
                if let info = try parseIPInfo(from: data, source: endpoint.name) {
                    return info
                }
            } catch {
                continue
            }
        }

        return IPInfo(
            ipAddress: "Unavailable",
            city: nil,
            region: nil,
            country: nil,
            isp: nil,
            organization: nil,
            timezone: nil,
            source: "No provider reached"
        )
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func parseIPInfo(from data: Data, source: String) throws -> IPInfo? {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else { return nil }

        let ip = stringValue(object, keys: ["ip", "query"])
        guard let ip, ip.isEmpty == false else { return nil }

        return IPInfo(
            ipAddress: ip,
            city: stringValue(object, keys: ["city"]),
            region: stringValue(object, keys: ["region", "regionName"]),
            country: stringValue(object, keys: ["country_name", "country", "countryCode"]),
            isp: stringValue(object, keys: ["isp"]),
            organization: stringValue(object, keys: ["org", "organization"]),
            timezone: stringValue(object, keys: ["timezone"]),
            source: source
        )
    }

    private func stringValue(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, value.isEmpty == false {
                return value
            }
        }
        return nil
    }
}
