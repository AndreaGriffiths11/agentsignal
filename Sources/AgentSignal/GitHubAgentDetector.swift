import Foundation
import Logging

final class GitHubAgentDetector {
    private let logger = Logger(label: "com.agentsignal.github-agent")
    private let apiClient = GitHubAPIClient()
    
    private var isMonitoring = false
    private var trackedIssues: Set<Int> = []
    private var trackedPullRequests: Set<Int> = []
    private var monitoredRepositories: [String] = []
    
    private struct AgentSession {
        let issueNumber: Int
        let repository: String
        let startTime: Date
        var hasEyesReaction: Bool
        var hasDraftPR: Bool
        var isCompleted: Bool
    }
    
    private var activeSessions: [Int: AgentSession] = [:]
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("Starting GitHub agent monitoring")
        isMonitoring = true
        
        loadConfiguration()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("Stopping GitHub agent monitoring")
        isMonitoring = false
        activeSessions.removeAll()
    }
    
    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        
        if let token = defaults.string(forKey: "GitHubToken") {
            apiClient.configure(token: token)
        } else {
            logger.warning("GitHub token not configured")
        }
        
        if let repositories = defaults.array(forKey: "MonitoredRepositories") as? [String] {
            monitoredRepositories = repositories
        } else {
            monitoredRepositories = []
            logger.warning("No repositories configured for monitoring")
        }
        
        logger.info("Loaded configuration: \(monitoredRepositories.count) repositories")
    }
    
    func checkForAgentActivity() async throws {
        guard isMonitoring,
              apiClient.isConfigured(),
              !monitoredRepositories.isEmpty else { return }
        
        for repository in monitoredRepositories {
            await checkRepositoryForAgentActivity(repository)
        }
        
        await checkForCompletedSessions()
    }
    
    private func checkRepositoryForAgentActivity(_ repository: String) async {
        do {
            let issues = try await apiClient.fetchIssues(for: repository)
            await processIssuesForAgentActivity(issues, in: repository)
        } catch {
            logger.error("Failed to fetch issues for \(repository): \(error.localizedDescription)")
        }
    }
    
    private func processIssuesForAgentActivity(_ issues: [GitHubIssue], in repository: String) async {
        for issue in issues {
            guard issue.state == "open" else { continue }
            
            let hasEyesReaction = (issue.reactions?.eyes ?? 0) > 0
            let isAssignedToBot = issue.assignee?.login.contains("bot") == true ||
                                  issue.assignee?.login.contains("agent") == true ||
                                  issue.assignee?.login.contains("copilot") == true
            
            if hasEyesReaction || isAssignedToBot {
                await handlePotentialAgentIssue(issue, in: repository)
            }
        }
    }
    
    private func handlePotentialAgentIssue(_ issue: GitHubIssue, in repository: String) async {
        let issueId = issue.number
        
        if var existingSession = activeSessions[issueId] {
            existingSession.hasEyesReaction = (issue.reactions?.eyes ?? 0) > 0
            
            if let prRef = issue.pullRequest {
                await checkPullRequestStatus(prRef.url, for: &existingSession)
            }
            
            activeSessions[issueId] = existingSession
            
        } else {
            var newSession = AgentSession(
                issueNumber: issueId,
                repository: repository,
                startTime: Date(),
                hasEyesReaction: (issue.reactions?.eyes ?? 0) > 0,
                hasDraftPR: false,
                isCompleted: false
            )
            
            if let prRef = issue.pullRequest {
                await checkPullRequestStatus(prRef.url, for: &newSession)
            }
            
            activeSessions[issueId] = newSession
            
            logger.info("Started tracking agent session for issue #\(issueId) in \(repository)")
        }
    }
    
    private func checkPullRequestStatus(_ prUrl: String, for session: inout AgentSession) async {
        do {
            let pr = try await apiClient.fetchPullRequest(url: prUrl)
            
            let wasDraftPR = session.hasDraftPR
            session.hasDraftPR = pr.draft
            
            if pr.draft && !wasDraftPR {
                logger.info("Draft PR #\(pr.number) created for issue #\(session.issueNumber)")
                
                NotificationCenter.default.post(
                    name: .githubAgentStateChanged,
                    object: nil,
                    userInfo: [
                        "createdPR": pr.number,
                        "repository": session.repository
                    ]
                )
            }
            
            if !pr.draft && pr.state == "open" && session.hasDraftPR {
                session.isCompleted = true
                logger.info("PR #\(pr.number) ready for review - agent session completed")
            }
            
        } catch {
            logger.error("Failed to check PR status: \(error.localizedDescription)")
        }
    }
    
    private func checkForCompletedSessions() async {
        let completedSessions = activeSessions.values.filter { session in
            if session.isCompleted {
                return true
            }
            
            let sessionDuration = Date().timeIntervalSince(session.startTime)
            let maxSessionDuration: TimeInterval = 3600
            
            if sessionDuration > maxSessionDuration && !session.hasEyesReaction {
                logger.info("Session timeout for issue #\(session.issueNumber) - assuming completed")
                return true
            }
            
            return false
        }
        
        for session in completedSessions {
            logger.info("Agent completed work on issue #\(session.issueNumber) in \(session.repository)")
            
            NotificationCenter.default.post(
                name: .githubAgentStateChanged,
                object: nil,
                userInfo: [
                    "completedIssue": session.issueNumber,
                    "repository": session.repository
                ]
            )
            
            activeSessions.removeValue(forKey: session.issueNumber)
        }
    }
    
    func configureRepositories(_ repositories: [String]) {
        monitoredRepositories = repositories
        UserDefaults.standard.set(repositories, forKey: "MonitoredRepositories")
        logger.info("Updated monitored repositories: \(repositories)")
    }
    
    func configureGitHubToken(_ token: String) {
        apiClient.configure(token: token)
        UserDefaults.standard.set(token, forKey: "GitHubToken")
        logger.info("GitHub token configured")
    }
    
    func getActiveSessionsCount() -> Int {
        return activeSessions.count
    }
    
    func getActiveSessions() -> [(issueNumber: Int, repository: String, duration: TimeInterval)] {
        return activeSessions.values.map { session in
            (
                issueNumber: session.issueNumber,
                repository: session.repository,
                duration: Date().timeIntervalSince(session.startTime)
            )
        }
    }
}