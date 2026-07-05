import Foundation

struct Release: Codable, Sendable {
    let tagName: String
    let name: String?
    let assets: [Asset]
    let tarballURL: String?
    let zipballURL: String?
    let prerelease: Bool
    let draft: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, assets, prerelease, draft
        case tarballURL = "tarball_url"
        case zipballURL = "zipball_url"
    }

    var displayName: String {
        name ?? tagName
    }

    var hasUploadedAssets: Bool {
        !assets.isEmpty
    }

    var sourceAssets: [Asset] {
        var result: [Asset] = []
        if let tarballURL = tarballURL {
            result.append(Asset(
                id: -1,
                name: "\(tagName)-source.tar.gz",
                browserDownloadURL: tarballURL,
                digest: nil,
                size: 0,
                contentType: "application/gzip"
            ))
        }
        if let zipballURL = zipballURL {
            result.append(Asset(
                id: -2,
                name: "\(tagName)-source.zip",
                browserDownloadURL: zipballURL,
                digest: nil,
                size: 0,
                contentType: "application/zip"
            ))
        }
        return result
    }

    var allAssets: [Asset] {
        if hasUploadedAssets {
            return assets
        }
        return sourceAssets
    }
}
