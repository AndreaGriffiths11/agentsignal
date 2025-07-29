import AppKit
import Foundation
import Logging

let logger = Logger(label: "com.agentsignal.main")

logger.info("Starting AgentSignal...")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let statusBarController = StatusBarController()
statusBarController.setupMenuBar()

let agentMonitor = AgentMonitor()
agentMonitor.setStatusBarController(statusBarController)

// Add test notifications menu item
let testMenu = NSMenu()
testMenu.addItem(withTitle: "Test Notifications", action: #selector(StatusBarController.testNotifications), keyEquivalent: "t")

if let menu = statusBarController.menu {
    menu.addItem(NSMenuItem.separator())
    let testMenuItem = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
    menu.addItem(testMenuItem)
    menu.setSubmenu(testMenu, for: testMenuItem)
}

logger.info("AgentSignal started successfully")
app.run()