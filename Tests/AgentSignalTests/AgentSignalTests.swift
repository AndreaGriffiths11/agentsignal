import XCTest
@testable import AgentSignal

final class AgentSignalTests: XCTestCase {
    func testGitHubAPIClientConfiguration() {
        let client = GitHubAPIClient()
        XCTAssertFalse(client.isConfigured())
        
        client.configure(token: "test-token")
        XCTAssertTrue(client.isConfigured())
    }
    
    func testStatusBarControllerInitialization() {
        let statusBarController = StatusBarController()
        XCTAssertNotNil(statusBarController)
    }
    
    func testVSCodeAgentDetectorInitialization() {
        let detector = VSCodeAgentDetector()
        XCTAssertNotNil(detector)
    }
    
    func testGitHubAgentDetectorInitialization() {
        let detector = GitHubAgentDetector()
        XCTAssertNotNil(detector)
        XCTAssertEqual(detector.getActiveSessionsCount(), 0)
    }
}