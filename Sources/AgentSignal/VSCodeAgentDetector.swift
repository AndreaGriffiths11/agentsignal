import ApplicationServices
import AppKit
import Foundation
import Logging

final class VSCodeAgentDetector {
    private let logger = Logger(label: "com.agentsignal.vscode")
    
    private var isMonitoring = false
    private var wasAgentActive = false
    private var currentTaskDescription = "Unknown task"
    
    private struct VSCodeWindow {
        let title: String
        let processId: pid_t
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("Starting VS Code agent monitoring")
        isMonitoring = true
        
        if !AXIsProcessTrusted() {
            logger.warning("Accessibility permissions not granted - VS Code monitoring may be limited")
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("Stopping VS Code agent monitoring")
        isMonitoring = false
    }
    
    func checkForAgentActivity() async {
        guard isMonitoring else { return }
        
        let isCurrentlyActive = await detectAgentMode()
        
        if wasAgentActive && !isCurrentlyActive {
            logger.info("VS Code agent completed task: \(currentTaskDescription)")
            
            NotificationCenter.default.post(
                name: .vsCodeAgentStateChanged,
                object: nil,
                userInfo: [
                    "isActive": false,
                    "taskDescription": currentTaskDescription
                ]
            )
        } else if !wasAgentActive && isCurrentlyActive {
            logger.info("VS Code agent started")
            
            NotificationCenter.default.post(
                name: .vsCodeAgentStateChanged,
                object: nil,
                userInfo: ["isActive": true]
            )
        }
        
        wasAgentActive = isCurrentlyActive
    }
    
    private func detectAgentMode() async -> Bool {
        let vsCodeWindows = getVSCodeWindows()
        
        for window in vsCodeWindows {
            if await isWindowInAgentMode(window) {
                return true
            }
        }
        
        return false
    }
    
    private func getVSCodeWindows() -> [VSCodeWindow] {
        var windows: [VSCodeWindow] = []
        
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  (bundleId.contains("com.microsoft.VSCodeInsiders") || 
                   bundleId.contains("com.microsoft.VSCode")) else { continue }
            
            if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                for windowInfo in windowList {
                    guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                          ownerPID == app.processIdentifier,
                          let windowTitle = windowInfo[kCGWindowName as String] as? String,
                          !windowTitle.isEmpty else { continue }
                    
                    windows.append(VSCodeWindow(title: windowTitle, processId: ownerPID))
                }
            }
        }
        
        return windows
    }
    
    private func isWindowInAgentMode(_ window: VSCodeWindow) async -> Bool {
        let agentModeIndicators = [
            "Claude is thinking",
            "Agent mode",
            "Tool invocation:",
            "read_file",
            "edit_file",
            "run_in_terminal",
            "Working on your request",
            "Analyzing",
            "Processing",
            "Running command"
        ]
        
        for indicator in agentModeIndicators {
            if window.title.contains(indicator) {
                updateTaskDescription(from: window.title)
                logger.debug("Agent mode detected in window: \(window.title)")
                return true
            }
        }
        
        if await checkAccessibilityBasedDetection(for: window) {
            return true
        }
        
        return false
    }
    
    private func checkAccessibilityBasedDetection(for window: VSCodeWindow) async -> Bool {
        guard AXIsProcessTrusted() else { return false }
        
        let app = AXUIElementCreateApplication(window.processId)
        var windowsRef: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else { return false }
        
        for axWindow in windows {
            if await checkWindowForAgentActivity(axWindow) {
                return true
            }
        }
        
        return false
    }
    
    private func checkWindowForAgentActivity(_ window: AXUIElement) async -> Bool {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        
        guard result == .success,
              let title = titleRef as? String else { return false }
        
        let agentIndicators = [
            "thinking...",
            "processing...",
            "working...",
            "agent mode",
            "tool:",
            "running:"
        ]
        
        let lowercaseTitle = title.lowercased()
        for indicator in agentIndicators {
            if lowercaseTitle.contains(indicator) {
                updateTaskDescription(from: title)
                return true
            }
        }
        
        return false
    }
    
    private func updateTaskDescription(from windowTitle: String) {
        if windowTitle.contains("edit_file") {
            currentTaskDescription = "Editing files"
        } else if windowTitle.contains("read_file") {
            currentTaskDescription = "Reading files"  
        } else if windowTitle.contains("run_in_terminal") {
            currentTaskDescription = "Running terminal commands"
        } else if windowTitle.contains("thinking") {
            currentTaskDescription = "Planning approach"
        } else if windowTitle.contains("analyzing") {
            currentTaskDescription = "Analyzing code"
        } else {
            currentTaskDescription = "Processing request"
        }
    }
}