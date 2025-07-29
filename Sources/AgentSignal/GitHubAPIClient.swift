import Foundation
import Logging

struct GitHubIssue: Codable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let assignee: GitHubUser?
    let reactions: GitHubReactions?
    let pullRequest: GitHubPullRequestReference?
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, state, assignee, reactions
        case pullRequest = "pull_request"
    }
}

struct GitHubUser: Codable {
    let id: Int
    let login: String
}

struct GitHubReactions: Codable {
    let eyes: Int
}

struct GitHubPullRequestReference: Codable {
    let url: String
}

struct GitHubPullRequest: Codable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let draft: Bool
    let user: GitHubUser
    let commits: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, state, draft, user, commits
    }
}

final class GitHubAPIClient {
    private let logger = Logger(label: "com.agentsignal.github")
    private let baseURL = "https://api.github.com"
    private var token: String?
    private let session = URLSession.shared
    
    enum GitHubError: Error, LocalizedError {
        case noToken
        case invalidURL
        case noData
        case invalidResponse
        case rateLimited
        case unauthorized
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .noToken:
                return "GitHub token not configured"
            case .invalidURL:
                return "Invalid GitHub API URL"
            case .noData:
                return "No data received from GitHub API"
            case .invalidResponse:
                return "Invalid response from GitHub API"
            case .rateLimited:
                return "GitHub API rate limit exceeded"
            case .unauthorized:
                return "GitHub API authentication failed"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    func configure(token: String) {
        self.token = token
        logger.info("GitHub API client configured")
    }
    
    func fetchIssues(for repository: String) async throws -> [GitHubIssue] {
        guard let token = token else {
            throw GitHubError.noToken
        }
        
        guard let url = URL(string: "\(baseURL)/repos/\(repository)/issues") else {
            throw GitHubError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        logger.debug("Fetching issues for repository: \(repository)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let issues = try JSONDecoder().decode([GitHubIssue].self, from: data)
                logger.debug("Fetched \(issues.count) issues")
                return issues
            case 401:
                throw GitHubError.unauthorized
            case 403:
                throw GitHubError.rateLimited
            default:
                logger.error("GitHub API returned status code: \(httpResponse.statusCode)")
                throw GitHubError.invalidResponse
            }
        } catch {
            if error is GitHubError {
                throw error
            } else {
                throw GitHubError.networkError(error)
            }
        }
    }
    
    func fetchPullRequest(url: String) async throws -> GitHubPullRequest {
        guard let token = token else {
            throw GitHubError.noToken
        }
        
        guard let apiURL = URL(string: url) else {
            throw GitHubError.invalidURL
        }
        
        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        logger.debug("Fetching pull request: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let pullRequest = try JSONDecoder().decode(GitHubPullRequest.self, from: data)
                logger.debug("Fetched pull request #\(pullRequest.number)")
                return pullRequest
            case 401:
                throw GitHubError.unauthorized
            case 403:
                throw GitHubError.rateLimited
            default:
                logger.error("GitHub API returned status code: \(httpResponse.statusCode)")
                throw GitHubError.invalidResponse
            }
        } catch {
            if error is GitHubError {
                throw error
            } else {
                throw GitHubError.networkError(error)
            }
        }
    }
    
    func isConfigured() -> Bool {
        return token != nil
    }
}