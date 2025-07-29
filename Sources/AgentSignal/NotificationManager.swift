import Foundation
import UserNotifications
import Logging

final class NotificationManager: NSObject {
    private let logger = Logger(label: "com.agentsignal.notifications")
    private let center = UNUserNotificationCenter.current()
    
    enum NotificationType {
        case vsCodeAgentCompleted(taskDescription: String)
        case githubAgentCompleted(issueNumber: Int, repository: String)
        case githubPullRequestCreated(prNumber: Int, repository: String)
        case monitoringStarted
        case monitoringStopped
        case error(message: String)
    }
    
    override init() {
        super.init()
        center.delegate = self
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                self?.logger.error("Failed to request notification permission: \(error.localizedDescription)")
                return
            }
            
            if granted {
                self?.logger.info("Notification permission granted")
            } else {
                self?.logger.warning("Notification permission denied")
            }
        }
    }
    
    func sendNotification(_ type: NotificationType) {
        let content = UNMutableNotificationContent()
        
        switch type {
        case .vsCodeAgentCompleted(let taskDescription):
            content.title = "VS Code Agent Complete"
            content.body = "Task completed: \(taskDescription)"
            content.sound = .default
            content.categoryIdentifier = "VSCODE_AGENT"
            
        case .githubAgentCompleted(let issueNumber, let repository):
            content.title = "GitHub Agent Complete"
            content.body = "Issue #\(issueNumber) completed in \(repository)"
            content.sound = .default
            content.categoryIdentifier = "GITHUB_AGENT"
            
        case .githubPullRequestCreated(let prNumber, let repository):
            content.title = "Pull Request Created"
            content.body = "PR #\(prNumber) created in \(repository)"
            content.sound = .default
            content.categoryIdentifier = "GITHUB_PR"
            
        case .monitoringStarted:
            content.title = "AgentSignal"
            content.body = "Monitoring started"
            content.sound = nil
            content.categoryIdentifier = "STATUS"
            
        case .monitoringStopped:
            content.title = "AgentSignal"
            content.body = "Monitoring stopped"
            content.sound = nil
            content.categoryIdentifier = "STATUS"
            
        case .error(let message):
            content.title = "AgentSignal Error"
            content.body = message
            content.sound = .defaultCritical
            content.categoryIdentifier = "ERROR"
        }
        
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        center.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send notification: \(error.localizedDescription)")
            } else {
                self?.logger.debug("Notification sent: \(content.title)")
            }
        }
    }
    
    func setupNotificationCategories() {
        let vsCodeCategory = UNNotificationCategory(
            identifier: "VSCODE_AGENT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let githubCategory = UNNotificationCategory(
            identifier: "GITHUB_AGENT",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_ISSUE",
                    title: "View Issue",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let prCategory = UNNotificationCategory(
            identifier: "GITHUB_PR",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_PR",
                    title: "View PR",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let statusCategory = UNNotificationCategory(
            identifier: "STATUS",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let errorCategory = UNNotificationCategory(
            identifier: "ERROR",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            vsCodeCategory,
            githubCategory,
            prCategory,
            statusCategory,
            errorCategory
        ])
        
        logger.info("Notification categories configured")
    }
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        logger.debug("All notifications cleared")
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "VIEW_ISSUE":
            logger.info("User requested to view issue")
        case "VIEW_PR":
            logger.info("User requested to view PR")
        default:
            break
        }
        
        completionHandler()
    }
}