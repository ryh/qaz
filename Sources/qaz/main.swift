#!/usr/bin/env swift

import Foundation

let args = Arguments.parse()

if args.help || !args.validate() {
    if !args.help {
        FileHandle.standardError.write(Data("Error: Invalid arguments\n\n".utf8))
    }
    print(Help.usage)
    exit(args.help ? 0 : 1)
}

guard let owner = args.owner, let repo = args.repo else {
    FileHandle.standardError.write(Data("Error: Invalid repository format. Use owner/repo\n".utf8))
    exit(1)
}

func log(_ msg: String) {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
}

@Sendable func logNoNewline(_ msg: String) {
    FileHandle.standardError.write(Data(msg.utf8))
}

let api = GitHubAPI()
let downloader = Downloader()

do {
    let release = try await api.fetchRelease(owner: owner, repo: repo, tag: args.tag)

    if args.verbose {
        log(Color.dim("Release: \(release.displayName)"))
        log(Color.dim("Assets: \(release.allAssets.count)"))
    }

    var asset: Asset?

    let allAssets = release.allAssets

    if args.interactive {
        asset = AssetSelector.select(from: allAssets)
        guard asset != nil else {
            log("Cancelled.")
            exit(0)
        }
    } else {
        let recommended = allAssets.filter { $0.isRecommended }
        if recommended.count == 1 {
            asset = recommended[0]
        } else if let first = recommended.first {
            asset = first
        } else if allAssets.count == 1 {
            asset = allAssets[0]
        } else {
            if allAssets.isEmpty {
                log(Color.red("Error: No assets found for this release."))
                exit(1)
            }
            log(Color.red("Error: Multiple assets found. Use --interactive to select."))
            for a in allAssets {
                log("  - \(a.name) [\(a.platformHint)] \(a.architectureHint)")
            }
            exit(1)
        }
    }

    guard let selectedAsset = asset else {
        log(Color.red("Error: No matching asset found for your system."))
        exit(1)
    }

    log("Downloading: \(Color.bold(selectedAsset.name))")

    let progressHandler: @Sendable (Downloader.Progress) -> Void = { progress in
        let received = progress.received
        let total = progress.total

        if total > 0 {
            let mb = Double(received) / 1024 / 1024
            let totalMb = Double(total) / 1024 / 1024
            let pct = Int(progress.percentage)
            logNoNewline("\r  \(Color.cyan(String(format: "%.1f", mb))) / \(String(format: "%.1f", totalMb)) MB (\(Color.green("\(pct)"))%)")
        } else {
            let mb = Double(received) / 1024 / 1024
            logNoNewline("\r  \(Color.cyan(String(format: "%.1f", mb))) MB")
        }
    }

    let filePath = try await downloader.download(
        url: selectedAsset.browserDownloadURL,
        fileName: selectedAsset.name,
        to: args.directory,
        quiet: args.quiet,
        verbose: args.verbose,
        progressHandler: progressHandler
    )

    log("")

    if let digest = selectedAsset.digest {
        try await HashVerifier.verify(filePath: filePath, expectedDigest: digest)
    }

    let extractedPath = try Extractor.extract(archivePath: filePath, verbose: args.verbose)

    if args.install {
        try Installer.install(from: extractedPath, verbose: args.verbose)
        log(Color.green("Installed"))
    } else {
        log(Color.green("Downloaded: ") + filePath)
    }

} catch {
    log(Color.red("Error: \(error.localizedDescription)"))
    exit(1)
}
