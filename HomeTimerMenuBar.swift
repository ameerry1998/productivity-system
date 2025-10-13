#!/usr/bin/swift

import Cocoa
import Foundation

class HomeTimerApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    
    let timerFile = "/var/log/home_usage.timer"
    let dailyLimit = 14400 // 4 hours in seconds
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "🏠 --:--"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Home Time Remaining", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(updateDisplay), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Update immediately and then every 30 seconds
        updateDisplay()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
    }
    
    @objc func statusBarButtonClicked() {
        updateDisplay()
    }
    
    @objc func updateDisplay() {
        let usage = getTodayUsage()
        let remaining = dailyLimit - usage
        
        if let button = statusItem.button {
            if remaining <= 0 {
                button.title = "🔒 LOCKED"
            } else {
                let hours = remaining / 3600
                let minutes = (remaining % 3600) / 60
                button.title = String(format: "🏠 %dh %02dm", hours, minutes)
            }
        }
        
        // Update menu
        if let menu = statusItem.menu, let firstItem = menu.items.first {
            let usedHours = usage / 3600
            let usedMinutes = (usage % 3600) / 60
            let remainingHours = remaining / 3600
            let remainingMinutes = (remaining % 3600) / 60
            
            firstItem.title = String(format: "Used: %dh %02dm | Remaining: %dh %02dm", 
                                    usedHours, usedMinutes, 
                                    max(0, remainingHours), max(0, remainingMinutes))
        }
    }
    
    func getTodayUsage() -> Int {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        
        guard let fileContents = try? String(contentsOfFile: timerFile, encoding: .utf8) else {
            return 0
        }
        
        let lines = fileContents.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix(todayStr + ":") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2, let usage = Int(parts[1]) {
                    return usage
                }
            }
        }
        
        return 0
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
}

// Main execution
let app = NSApplication.shared
let delegate = HomeTimerApp()
app.delegate = delegate
app.setActivationPolicy(.accessory) // This makes it not appear in the Dock
app.run()

