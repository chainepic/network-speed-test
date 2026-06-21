import Foundation

enum EndpointCatalog {
    static let ipLookup: [TestEndpoint] = [
        TestEndpoint(
            id: "ipapi",
            name: "ipapi.co",
            regionCode: nil,
            url: URL(string: "https://ipapi.co/json/")!,
            kind: .ipLookup
        ),
        TestEndpoint(
            id: "ipwhois",
            name: "ipwho.is",
            regionCode: nil,
            url: URL(string: "https://ipwho.is/")!,
            kind: .ipLookup
        )
    ]

    static let download: [TestEndpoint] = [
        TestEndpoint(
            id: "cloudflare-25mb",
            name: "Cloudflare 25 MB",
            regionCode: nil,
            url: URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!,
            kind: .download(bytes: 25_000_000)
        ),
        TestEndpoint(
            id: "thinkbroadband-10mb",
            name: "ThinkBroadband 10 MB",
            regionCode: nil,
            url: URL(string: "https://ipv4.download.thinkbroadband.com/10MB.zip")!,
            kind: .download(bytes: 10_000_000)
        )
    ]

    static let upload: [TestEndpoint] = [
        TestEndpoint(
            id: "cloudflare-upload",
            name: "Cloudflare Upload",
            regionCode: nil,
            url: URL(string: "https://speed.cloudflare.com/__up")!,
            kind: .upload(bytes: 1_000_000)
        ),
        TestEndpoint(
            id: "httpbin-post",
            name: "httpbin.org fallback",
            regionCode: nil,
            url: URL(string: "https://httpbin.org/post")!,
            kind: .upload(bytes: 512_000)
        )
    ]

    static let regional: [TestEndpoint] = [
        regionalEndpoint(id: "us-west", name: "US West", code: "US-W", url: "https://www.google.com/generate_204"),
        regionalEndpoint(id: "us-east", name: "US East", code: "US-E", url: "https://dynamodb.us-east-1.amazonaws.com/"),
        regionalEndpoint(id: "europe", name: "Europe", code: "EU", url: "https://dynamodb.eu-west-1.amazonaws.com/"),
        regionalEndpoint(id: "japan", name: "Japan", code: "JP", url: "https://dynamodb.ap-northeast-1.amazonaws.com/"),
        regionalEndpoint(id: "singapore", name: "Singapore", code: "SG", url: "https://dynamodb.ap-southeast-1.amazonaws.com/"),
        regionalEndpoint(id: "australia", name: "Australia", code: "AU", url: "https://dynamodb.ap-southeast-2.amazonaws.com/"),
        regionalEndpoint(id: "china", name: "Mainland China", code: "CN", url: "https://www.baidu.com/"),

        regionalEndpoint(id: "us-central", name: "US Central", code: "US-C", url: "https://dynamodb.us-east-2.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "canada", name: "Canada", code: "CA", url: "https://dynamodb.ca-central-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "brazil", name: "Brazil", code: "BR", url: "https://dynamodb.sa-east-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "united-kingdom", name: "United Kingdom", code: "UK", url: "https://dynamodb.eu-west-2.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "germany", name: "Germany", code: "DE", url: "https://dynamodb.eu-central-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "france", name: "France", code: "FR", url: "https://dynamodb.eu-west-3.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "sweden", name: "Sweden", code: "SE", url: "https://dynamodb.eu-north-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "italy", name: "Italy", code: "IT", url: "https://dynamodb.eu-south-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "india", name: "India", code: "IN", url: "https://dynamodb.ap-south-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "south-korea", name: "South Korea", code: "KR", url: "https://dynamodb.ap-northeast-2.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "hong-kong", name: "Hong Kong", code: "HK", url: "https://dynamodb.ap-east-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "indonesia", name: "Indonesia", code: "ID", url: "https://dynamodb.ap-southeast-3.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "uae", name: "UAE", code: "AE", url: "https://dynamodb.me-central-1.amazonaws.com/", requiresMembership: true),
        regionalEndpoint(id: "south-africa", name: "South Africa", code: "ZA", url: "https://dynamodb.af-south-1.amazonaws.com/", requiresMembership: true)
    ]

    static var freeRegional: [TestEndpoint] {
        regional.filter { $0.requiresMembership == false }
    }

    static var premiumRegional: [TestEndpoint] {
        regional.filter(\.requiresMembership)
    }

    static func regionalEndpoints(includePremium: Bool) -> [TestEndpoint] {
        includePremium ? regional : freeRegional
    }

    private static func regionalEndpoint(
        id: String,
        name: String,
        code: String,
        url: String,
        requiresMembership: Bool = false
    ) -> TestEndpoint {
        TestEndpoint(
            id: id,
            name: name,
            regionCode: code,
            url: URL(string: url)!,
            kind: .regionalProbe,
            requiresMembership: requiresMembership
        )
    }
}
