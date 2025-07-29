import Foundation
import AppKit
import WebKit

public enum PetType {
    case dog
    case cat
    case chicken
    case duck
    
    var emoji: String {
        switch self {
        case .dog: return "🐕"
        case .cat: return "🐱"
        case .chicken: return "🐔"
        case .duck: return "🦆"
        }
    }
    
    var animation: String {
        // These would be replaced with actual CSS animations
        switch self {
        case .dog: return "bounce"
        case .cat: return "walk"
        case .chicken: return "flap"
        case .duck: return "waddle"
        }
    }
}

public class PetNotificationView: NSViewController {
    private var webView: WKWebView!
    private var pet: PetType
    private var message: String
    
    init(pet: PetType, message: String) {
        self.pet = pet
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        view = webView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load the pet animation and message
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    background: transparent;
                    margin: 0;
                    padding: 10px;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                }
                .pet-container {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                    background: rgba(30, 30, 30, 0.9);
                    border-radius: 8px;
                    padding: 12px;
                    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
                }
                .pet {
                    font-size: 24px;
                    animation: \(pet.animation) 1s infinite;
                }
                .message {
                    color: #ffffff;
                    font-size: 14px;
                }
                @keyframes bounce {
                    0%, 100% { transform: translateY(0); }
                    50% { transform: translateY(-10px); }
                }
                @keyframes walk {
                    0% { transform: translateX(-5px); }
                    50% { transform: translateX(5px); }
                    100% { transform: translateX(-5px); }
                }
                @keyframes flap {
                    0%, 100% { transform: rotate(-5deg); }
                    50% { transform: rotate(5deg); }
                }
                @keyframes waddle {
                    0% { transform: rotate(-3deg); }
                    50% { transform: rotate(3deg); }
                    100% { transform: rotate(-3deg); }
                }
            </style>
        </head>
        <body>
            <div class="pet-container">
                <div class="pet">\(pet.emoji)</div>
                <div class="message">\(message)</div>
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
}
