import Foundation

enum GitHubError: Error, LocalizedError {
    case invalidURL
    case repoNotFound(String)
    case noReleases(String)
    case rateLimited
    case unauthorized
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .repoNotFound(let msg):
            return msg
        case .noReleases(let msg):
            return msg
        case .rateLimited:
            return "Rate limited. Set GITHUB_TOKEN for higher limits"
        case .unauthorized:
            return "Unauthorized. Check your GITHUB_TOKEN"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .decodingError(let err):
            return "Failed to parse response: \(err.localizedDescription)"
        }
    }
}

final class GitHubAPI: Sendable {
    private let session = URLSession.shared
    private let token: String?

    init() {
        token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
            ?? ProcessInfo.processInfo.environment["GH_TOKEN"]
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func fetchRelease(owner: String, repo: String, tag: String? = nil) async throws -> Release {
        let urlString: String
        if let tag = tag {
            urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/tags/\(tag)"
        } else {
            urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        }

        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        let request = makeRequest(url: url)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.rateLimited
        case 404:
            if tag != nil {
                if try await repoExists(owner: owner, repo: repo) {
                    throw GitHubError.noReleases("Tag not found: \(tag!)")
                } else {
                    throw GitHubError.repoNotFound("Repository not found: \(owner)/\(repo)")
                }
            } else {
                if try await repoExists(owner: owner, repo: repo) {
                    throw GitHubError.noReleases("No releases found: \(owner)/\(repo)")
                } else {
                    throw GitHubError.repoNotFound("Repository not found: \(owner)/\(repo)")
                }
            }
        default:
            throw GitHubError.repoNotFound("GitHub API error: HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Release.self, from: data)
        } catch {
            throw GitHubError.decodingError(error)
        }
    }

    private func repoExists(owner: String, repo: String) async throws -> Bool {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)") else {
            return false
        }
        let request = makeRequest(url: url)
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}
