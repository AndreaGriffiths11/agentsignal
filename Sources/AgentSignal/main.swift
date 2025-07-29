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

logger.info("AgentSignal started successfully")
app.run()