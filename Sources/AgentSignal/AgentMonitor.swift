import Foundation
import Logging

final class AgentMonitor {
    private let logger = Logger(label: "com.agentsignal.monitor")
    private let notificationManager = NotificationManager()
    private let vsCodeDetector = VSCodeAgentDetector()
    private let githubDetector = GitHubAgentDetector()
    
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    
    private weak var statusBarController: StatusBarController?
    
    init() {
        setupNotificationObservers()
    }
    
    func setStatusBarController(_ controller: StatusBarController) {
        self.statusBarController = controller
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleMonitoringRequested),
            name: .toggleMonitoring,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vsCodeAgentStateChanged),
            name: .vsCodeAgentStateChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(githubAgentStateChanged),
            name: .githubAgentStateChanged,
            object: nil
        )
    }
    
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("Monitoring already active")
            return
        }
        
        logger.info("Starting agent monitoring")
        isMonitoring = true
        
        vsCodeDetector.startMonitoring()
        githubDetector.startMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performMonitoringCycle()
        }
        
        statusBarController?.updateState(isMonitoring: true)
        notificationManager.sendNotification(NotificationManager.NotificationType.monitoringStarted)
        
        logger.info("Agent monitoring started successfully")
    }
    
    func stopMonitoring() {
        guard isMonitoring else {
            logger.warning("Monitoring not active")
            return
        }
        
        logger.info("Stopping agent monitoring")
        isMonitoring = false
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        vsCodeDetector.stopMonitoring()
        githubDetector.stopMonitoring()
        
        statusBarController?.updateState(isMonitoring: false)
        notificationManager.sendNotification(NotificationManager.NotificationType.monitoringStopped)
        
        logger.info("Agent monitoring stopped")
    }
    
    private func performMonitoringCycle() {
        logger.debug("Performing monitoring cycle")
        
        Task {
            do {
                await vsCodeDetector.checkForAgentActivity()
                try await githubDetector.checkForAgentActivity()
            } catch {
                logger.error("Error during monitoring cycle: \(error.localizedDescription)")
                notificationManager.sendNotification(NotificationManager.NotificationType.error(message: error.localizedDescription))
            }
        }
    }
    
    @objc private func toggleMonitoringRequested() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    @objc private func vsCodeAgentStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isActive = userInfo["isActive"] as? Bool else { return }
        
        logger.info("VS Code agent state changed: \(isActive ? "active" : "inactive")")
        
        statusBarController?.updateState(isMonitoring: isMonitoring, isAgentActive: isActive)
        
        if !isActive, let taskDescription = userInfo["taskDescription"] as? String {
            notificationManager.sendNotification(NotificationManager.NotificationType.vsCodeAgentCompleted(taskDescription: taskDescription))
        }
    }
    
    @objc private func githubAgentStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let issueNumber = userInfo["completedIssue"] as? Int,
           let repository = userInfo["repository"] as? String {
            logger.info("GitHub agent completed issue #\(issueNumber) in \(repository)")
            notificationManager.sendNotification(NotificationManager.NotificationType.githubAgentCompleted(issueNumber: issueNumber, repository: repository))
        }
        
        if let prNumber = userInfo["createdPR"] as? Int,
           let repository = userInfo["repository"] as? String {
            logger.info("GitHub agent created PR #\(prNumber) in \(repository)")
            notificationManager.sendNotification(NotificationManager.NotificationType.githubPullRequestCreated(prNumber: prNumber, repository: repository))
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        monitoringTimer?.invalidate()
    }
}

extension Notification.Name {
    static let vsCodeAgentStateChanged = Notification.Name("vsCodeAgentStateChanged")
    static let githubAgentStateChanged = Notification.Name("githubAgentStateChanged")
}