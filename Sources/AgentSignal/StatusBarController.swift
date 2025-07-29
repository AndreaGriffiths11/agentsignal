import AppKit
import Foundation
import Logging

final class StatusBarController {
    private let logger = Logger(label: "com.agentsignal.statusbar")
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    private enum MenuState {
        case idle
        case monitoring
        case agentActive
    }
    
    private var currentState: MenuState = .idle {
        didSet {
            updateStatusIcon()
        }
    }
    
    func setupMenuBar() {
        logger.info("Setting up menu bar")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusItem = statusItem else {
            logger.error("Failed to create status item")
            return
        }
        
        setupMenu()
        updateStatusIcon()
        
        statusItem.menu = menu
        logger.info("Menu bar setup complete")
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "AgentSignal - Idle", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu?.addItem(statusMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let toggleMenuItem = NSMenuItem(
            title: "Start Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: "m"
        )
        toggleMenuItem.target = self
        menu?.addItem(toggleMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let preferencesMenuItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesMenuItem.target = self
        menu?.addItem(preferencesMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(
            title: "Quit AgentSignal",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu?.addItem(quitMenuItem)
    }
    
    private func updateStatusIcon() {
        guard let statusItem = statusItem else { return }
        
        let iconName: String
        let tooltip: String
        
        switch currentState {
        case .idle:
            iconName = "circle"
            tooltip = "AgentSignal - Idle"
        case .monitoring:
            iconName = "circle.fill"
            tooltip = "AgentSignal - Monitoring"
        case .agentActive:
            iconName = "gear"
            tooltip = "AgentSignal - Agent Active"
        }
        
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip) {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.toolTip = tooltip
        }
        
        updateMenuTitle()
    }
    
    private func updateMenuTitle() {
        guard let menu = menu,
              let statusMenuItem = menu.items.first else { return }
        
        let title: String
        switch currentState {
        case .idle:
            title = "AgentSignal - Idle"
        case .monitoring:
            title = "AgentSignal - Monitoring"
        case .agentActive:
            title = "AgentSignal - Agent Active"
        }
        
        statusMenuItem.title = title
    }
    
    func updateState(isMonitoring: Bool, isAgentActive: Bool = false) {
        if isAgentActive {
            currentState = .agentActive
        } else if isMonitoring {
            currentState = .monitoring
        } else {
            currentState = .idle
        }
        
        updateToggleMenuItem()
    }
    
    private func updateToggleMenuItem() {
        guard let menu = menu,
              let toggleMenuItem = menu.item(withTitle: "Start Monitoring") ?? menu.item(withTitle: "Stop Monitoring") else { return }
        
        switch currentState {
        case .idle:
            toggleMenuItem.title = "Start Monitoring"
        case .monitoring, .agentActive:
            toggleMenuItem.title = "Stop Monitoring"
        }
    }
    
    @objc private func toggleMonitoring() {
        logger.info("Toggle monitoring requested")
        NotificationCenter.default.post(name: .toggleMonitoring, object: nil)
    }
    
    @objc private func showPreferences() {
        logger.info("Preferences requested")
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "GitHub API configuration and monitoring settings will be available in a future version."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quit() {
        logger.info("Quit requested")
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let toggleMonitoring = Notification.Name("toggleMonitoring")
}