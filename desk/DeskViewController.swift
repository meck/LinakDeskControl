//
//  DeskViewcontroller.swift
//  desk
//
//  Created by Forti on 18/05/2020.
//  Copyright © 2020 Forti. All rights reserved.
//

import Cocoa

class DeskViewController: NSViewController {
    private var deskConnect: DeskConnect!
    private var longClick: NSPressGestureRecognizer?
    private var userDefaults: UserDefaults?
    private var upTimer : Timer = Timer.init()
    private var downTimer : Timer = Timer.init()
    private var timeout : Int = 5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.deskConnect = DeskConnect()
        
        self.buttonUp.isEnabled = false
        self.buttonDown.isEnabled = false
        
        self.deskConnect.currentPosition.asObservable().subscribe({ value in
            if let position = value.element {
                if (position > 0) {
                    self.currentValue.stringValue = String(format:"%.1f", position)
                    self.currentPosition = position
                }
            }
            
        }).disposed(by: self.deskConnect.dispose)
        
        self.deskConnect.deviceName.asObservable().subscribe({ value in
            self.deskName.stringValue = "\(value.element ?? "Unknown desk")"
            self.buttonUp.isEnabled = true
            self.buttonDown.isEnabled = true
        }).disposed(by: self.deskConnect.dispose)
        
        self.userDefaults = UserDefaults.init(suiteName: "positions")
        
        UserDefaults.standard.register(defaults: ["periodic-stand" : true, "stand-per-hour" : 10])
        
        self.initSavedValues()

        self.updateTimer()
        
        self.buttonUp.sendAction(on: .leftMouseDown)
        self.buttonUp.isContinuous = true
        self.buttonUp.setPeriodicDelay(0, interval: 0.7)
        
        self.buttonDown.sendAction(on: .leftMouseDown)
        self.buttonDown.isContinuous = true
        self.buttonDown.setPeriodicDelay(0, interval: 0.7)
    }
    
    
    var currentPosition: Double!
    @IBOutlet var currentValue: NSTextField!
    @IBOutlet var deskName: NSTextField!
    @IBOutlet var buttonUp: NSButton!
    @IBOutlet var buttonDown: NSButton!
    
    @IBOutlet var buttonMoveToSit: NSButton!
    @IBOutlet var buttonMoveToStand: NSButton!
    
    @IBOutlet var sitPosition: NSTextField!
    @IBOutlet var standPosition: NSTextField!
    
    @IBOutlet var standPerHourLabel: NSTextField!
    @IBOutlet var periodicStand: NSSwitch!
    @IBOutlet var periodicStandStepper: NSStepper!
    @IBOutlet var periodicTimeoutLabel: NSTextField!
    @IBOutlet var periodicTimeoutStepper: NSStepper!
    
    var isMovingToPositionValue = false
    var moveToPositionValue = 70.0
    
    var isWaitingForSecondPress = false
    @objc func stopMoving() {
        self.deskConnect.stopMoving()
        self.isWaitingForSecondPress = true
    }
    
    @objc func clearIsWairingForSecondPress() {
        self.isWaitingForSecondPress = false
    }
    
    func handleStopMovingIfSingleClick() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(clearIsWairingForSecondPress), object: nil)
        
        if (self.isWaitingForSecondPress == false) {
            perform(#selector(stopMoving), with: nil, afterDelay: 0.18)
        }
        
        perform(#selector(clearIsWairingForSecondPress), with: nil, afterDelay: 0.2)
    }
    
    @IBAction func up(_ sender: NSButton) {
        self.deskConnect.moveUp()
        self.handleStopMovingIfSingleClick()
    }
    
    @IBAction func down(_ sender: NSButton) {
        self.deskConnect.moveDown()
        self.handleStopMovingIfSingleClick()
    }
    
    @IBAction func saveAsSitPosition(_ sender: NSButton) {
        self.userDefaults?.set(self.currentPosition, forKey: "sit-position")
        self.sitPosition.stringValue = String(format:"%.1f", self.currentPosition)
    }
    
    @IBAction func saveAsStandPosition(_ sender: NSButton) {
        self.userDefaults?.set(self.currentPosition, forKey: "stand-position")
        self.standPosition.stringValue = String(format:"%.1f", self.currentPosition)
    }
    
    @IBAction func moveToSitPosition(_ sender: NSButton) {
        let position = self.userDefaults?.double(forKey: "sit-position") ?? .nan
        if (position != .nan) {
            self.deskConnect.moveToPosition(position: position)
        }
    }
    
    @IBAction func moveToStandPosition(_ sender: NSButton) {
        let position = self.userDefaults?.double(forKey: "stand-position") ?? .nan
        if (position != .nan) {
            self.deskConnect.moveToPosition(position: position)
        }
    }
    
    @IBAction func updatePeriodicStandTime(_ sender: NSStepper) {
        self.standPerHourLabel.stringValue = String(format: "%.2d", sender.intValue)
        self.userDefaults?.setValue(sender.intValue, forKey: "stand-per-hour")
        self.updateTimer()
    }
    
    @IBAction func updatePeriodicTimeEnable(_ sender: NSSwitch) {
        self.userDefaults?.setValue((sender.state == NSControl.StateValue.on) , forKey: "periodic-stand")
        self.updateTimer()
    }
    
    @IBAction func updatePeriodicTimeout(_ sender: NSStepper) {
        self.periodicTimeoutLabel.stringValue = String(format: "%.2d", sender.intValue)
        self.userDefaults?.setValue(sender.intValue, forKey: "stand-timeout")
        self.timeout = Int(sender.intValue)
    }
    
    
    @IBAction func stop(_ sender: NSButton) {
        self.deskConnect.stopMoving()
    }
    
    private func initSavedValues() {
        if let sitPosition = self.userDefaults?.double(forKey: "sit-position") {
            self.sitPosition.stringValue = String(format:"%.1f", sitPosition)
        }
        
        if let standPosition = self.userDefaults?.double(forKey: "stand-position") {
            self.standPosition.stringValue = String(format:"%.1f", standPosition)
        }
        
        if let periodicStand = self.userDefaults?.bool(forKey: "periodic-stand") {
            self.periodicStand.state = periodicStand ? NSControl.StateValue.on : NSControl.StateValue.off
        }
        
        if let standPerHour = self.userDefaults?.integer(forKey: "stand-per-hour") {
            self.periodicStandStepper.intValue = Int32(standPerHour)
            self.standPerHourLabel.stringValue = String(format: "%.2d", standPerHour)
        }
        
        if let periodicTimeout = self.userDefaults?.integer(forKey: "stand-timeout") {
            self.periodicTimeoutStepper.intValue = Int32(periodicTimeout)
            self.standPerHourLabel.stringValue = String(format: "%.2d", periodicTimeout)
            self.timeout = periodicTimeout
        }
    }
    
    private func updateTimer() {
        upTimer.invalidate()
        downTimer.invalidate()
        
        if let periodicStand = self.userDefaults?.bool(forKey: "periodic-stand") {
            if (!periodicStand) {return}
        }
        
        if let standPerHour = self.userDefaults?.integer(forKey: "stand-per-hour") {
            
            let upTime  = TimeInterval((60 - standPerHour) * 60)
            let downTime = TimeInterval(60 * 60)
            
            upTimer = Timer.scheduledTimer(withTimeInterval: upTime, repeats: true, block: { timer in
                var lastEvent:CFTimeInterval = 0
                lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
                if lastEvent < Double(self.timeout * 60) {
                    self.moveToStandPosition(NSButton.init())
                }
            })
            
            downTimer = Timer.scheduledTimer(withTimeInterval: downTime, repeats: true, block: { timer in
                var lastEvent:CFTimeInterval = 0
                lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
                if lastEvent < Double(self.timeout * 60) {
                    self.moveToSitPosition(NSButton.init())
                }
            })
            
            upTimer.tolerance = 10
            downTimer.tolerance = 10
        }
    }
}

extension DeskViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> DeskViewController {
        //1.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        //2.
        let identifier = NSStoryboard.SceneIdentifier("DeskViewController")
        //3.
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? DeskViewController else {
            fatalError("Why cant i find QuotesViewController? - Check Main.storyboard")
        }
        return viewcontroller
    }
}

