import Foundation
import AppKit
import UserNotifications
import Logging
import WebKit

public final class NotificationManager: NSObject {
    private let logger = Logger(label: "com.agentsignal.notifications")
    private var center: UNUserNotificationCenter? = nil
    
    public enum NotificationType: Equatable {
        case vsCodeAgentCompleted(taskDescription: String)
        case githubAgentCompleted(issueNumber: Int, repository: String)
        case githubPullRequestCreated(prNumber: Int, repository: String)
        case monitoringStarted
        case monitoringStopped
        case error(message: String)
    }
    
    public override init() {
        super.init()
        
        // For development testing, we'll skip system notifications and just show the pet window
        logger.info("Initializing notification manager in development mode")
    }
    
    private func requestNotificationPermission() {
        guard let center = self.center else { return }
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
    
    private func configureNotificationCategories() {
        guard let center = self.center else { return }
        
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
    
    public func sendNotification(_ type: NotificationType) {
        // Create and configure the pet notification window
        let (pet, message) = getPetAndMessage(for: type)
        let petView = PetNotificationView(pet: pet, message: message)
        
        // Create a window to show the pet
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = petView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Position the window in the bottom right corner
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let newOrigin = NSPoint(
                x: screenRect.maxX - windowRect.width - 20,
                y: screenRect.minY + 20
            )
            window.setFrameOrigin(newOrigin)
        }
        
        // Show the window and automatically close it after a delay
        window.orderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.close()
            })
        }
        
        // Log the notification for development
        logger.info("Notification: \(message)")
    }
    
    private func getPetAndMessage(for type: NotificationType) -> (PetType, String) {
        switch type {
        case .vsCodeAgentCompleted(let taskDescription):
            return (.dog, "Task completed: \(taskDescription)")
            
        case .githubAgentCompleted(let issueNumber, let repository):
            return (.cat, "Issue #\(issueNumber) completed in \(repository)")
            
        case .githubPullRequestCreated(let prNumber, let repository):
            return (.duck, "PR #\(prNumber) created in \(repository)")
            
        case .monitoringStarted:
            return (.chicken, "Monitoring started")
            
        case .monitoringStopped:
            return (.chicken, "Monitoring stopped")
            
        case .error(let message):
            return (.cat, "Error: \(message)") // Cats look concerned when there's an error!
        }
    }
    
    public func clearAllNotifications() {
        center?.removeAllPendingNotificationRequests()
        center?.removeAllDeliveredNotifications()
        logger.debug("All notifications cleared")
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    public func userNotificationCenter(
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
