//
//  AppDelegate.swift
//  desk
//
//  Created by Forti on 18/05/2020.
//  Copyright © 2020 Forti. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let popover = NSPopover()
    
    var eventMonitor: EventMonitor?
    
    var deskConnect: DeskConnect! = DeskConnect()
    var userDefaults: UserDefaults?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        self.userDefaults = UserDefaults.init(suiteName: "settings")
        UserDefaults.standard.register(defaults: ["periodic-stand" : false, "stand-per-hour" : 10])
        
        self.initSavedValues()
        
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("table"))
            button.action = #selector(togglePopover(_:))
        }
        
        popover.contentViewController = DeskViewController.freshController()
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
          if let strongSelf = self, strongSelf.popover.isShown {
            strongSelf.closePopover(sender: event)
          }
        }
    }

    
    @objc func togglePopover(_ sender: Any?) {
      if popover.isShown {
        closePopover(sender: sender)
      } else {
        showPopover(sender: sender)
      }
    }

    func showPopover(sender: Any?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        
        eventMonitor?.start()
    }

    func closePopover(sender: Any?) {
      popover.performClose(sender)
    }
    
    private func initSavedValues() {
        if let sitPosition = self.userDefaults?.double(forKey: "sit-position") {
            self.deskConnect.autoSitPos = sitPosition
        }
        
        if let standPosition = self.userDefaults?.double(forKey: "stand-position") {
            self.deskConnect.autoStandPos = standPosition
        }
        
        if let periodicStand = self.userDefaults?.bool(forKey: "periodic-stand") {
            if let standPerHour = self.userDefaults?.integer(forKey: "stand-per-hour") {
                if (!periodicStand) {
                    self.deskConnect.standPerHour = nil
                } else {
                    self.deskConnect.standPerHour = TimeInterval(standPerHour * 60)
                }
            }
        }
        
        if let periodicTimeout = self.userDefaults?.integer(forKey: "stand-timeout") {
            self.deskConnect.inactivityTimeout = TimeInterval(periodicTimeout * 60)
        }
    }
}
