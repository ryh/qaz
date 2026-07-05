import Foundation

struct Arguments: Sendable {
    let repository: String?
    let owner: String?
    let repo: String?
    let tag: String?
    let directory: String
    let quiet: Bool
    let interactive: Bool
    let verbose: Bool
    let install: Bool
    let help: Bool

    static func parse() -> Arguments {
        let args = CommandLine.arguments
        var input: String?
        var tag: String?
        var directory = FileManager.default.currentDirectoryPath
        var quiet = true
        var interactive = false
        var verbose = false
        var install = false
        var help = false

        var i = 1
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-q", "--quiet":
                quiet = true
            case "-i", "--interactive":
                interactive = true
            case "-v", "--verbose":
                verbose = true
                quiet = false
            case "-I", "--install":
                install = true
            case "-h", "--help":
                help = true
            case "-t", "--tag":
                i += 1
                if i < args.count {
                    tag = args[i]
                }
            case "-d", "--directory":
                i += 1
                if i < args.count {
                    directory = NSString(string: args[i]).expandingTildeInPath
                }
            default:
                if !arg.hasPrefix("-") && input == nil {
                    input = arg
                }
            }
            i += 1
        }

        var owner: String?
        var repo: String?
        var extractedTag: String?

        if let input = input {
            if let parsed = parseGitHubURL(input) {
                owner = parsed.owner
                repo = parsed.repo
                extractedTag = parsed.tag
            } else if let parsed = parseOwnerRepo(input) {
                owner = parsed.owner
                repo = parsed.repo
            }
        }

        if tag == nil && extractedTag != nil {
            tag = extractedTag
        }

        return Arguments(
            repository: input,
            owner: owner,
            repo: repo,
            tag: tag,
            directory: directory,
            quiet: quiet,
            interactive: interactive,
            verbose: verbose,
            install: install,
            help: help
        )
    }

    private static func parseGitHubURL(_ url: String) -> (owner: String, repo: String, tag: String?)? {
        let patterns = [
            "https://github.com/([^/]+)/([^/]+)/releases/tag/([^/]+)",
            "https://github.com/([^/]+)/([^/]+)",
            "https://github.com/([^/]+)/([^/]+)/",
            "http://github.com/([^/]+)/([^/]+)/releases/tag/([^/]+)",
            "http://github.com/([^/]+)/([^/]+)",
            "http://github.com/([^/]+)/([^/]+)/",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(url.startIndex..., in: url)
                if let match = regex.firstMatch(in: url, range: range) {
                    let owner = String(url[Range(match.range(at: 1), in: url)!])
                    let repo = String(url[Range(match.range(at: 2), in: url)!])
                    var tag: String?
                    if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                        tag = String(url[Range(match.range(at: 3), in: url)!])
                    }
                    return (owner, repo, tag)
                }
            }
        }
        return nil
    }

    private static func parseOwnerRepo(_ input: String) -> (owner: String, repo: String)? {
        let parts = input.split(separator: "/")
        if parts.count == 2 {
            let owner = String(parts[0])
            let repo = String(parts[1]).replacingOccurrences(of: ".git", with: "")
            if !owner.isEmpty && !repo.isEmpty {
                return (owner, repo)
            }
        }
        return nil
    }

    func validate() -> Bool {
        if help {
            return true
        }
        guard let owner = owner, let repo = repo else {
            return false
        }
        guard !owner.isEmpty, !repo.isEmpty else {
            return false
        }
        return true
    }
}
