//
//  MasterViewController.swift
//  BT Guitar Interface
//
//  Created by JP Carrascal on 05/03/16.
//  Copyright © 2016 Spacebarman. All rights reserved.
//

import Cocoa
import OSCKit
import IOBluetooth

////class MasterViewController: NSViewController {
class MasterViewController: NSViewController, NRFManagerDelegate {

    @IBOutlet weak var outputSelect: NSTabViewItem!
    @IBOutlet weak var scanProgress: NSProgressIndicator!
    @IBOutlet weak var scanText: NSTextField!
    @IBOutlet weak var BTConnectText: NSButton!
    @IBOutlet weak var BTIndicator: NSImageView!
    @IBOutlet weak var OSCActive: NSButton!
    @IBOutlet weak var MIDIActive: NSButton!
    @IBOutlet weak var noneActive: NSButton!
    @IBOutlet weak var OSCAddress: NSTextField!
    @IBOutlet weak var OSCPort: NSTextField!
    @IBOutlet weak var OSCAddrRibbon: NSTextField!
    @IBOutlet weak var OSCAddrKnob: NSTextField!
    @IBOutlet weak var OSCAddrAccel: NSTextField!
    @IBOutlet weak var MIDIRefreshButton: NSButton!
    @IBOutlet weak var MIDIDevice: NSComboBox!
    @IBOutlet weak var MIDIChannel: NSComboBox!
    @IBOutlet weak var MIDICCRibbon: NSTextField!
    @IBOutlet weak var MIDICCKnob: NSTextField!
    @IBOutlet weak var MIDICCAccX: NSTextField!
    @IBOutlet weak var MIDICCAccY: NSTextField!
    @IBOutlet weak var MIDICCAccZ: NSTextField!
    
    private var receivedMessages = [String]()
    private var prevOSCValues = [Int]()
    private var prevMIDIValues = [UInt8]()
    private var deviceListNames = [String]()
    private var BTStatus = false;
    private var defaults = NSDictionary(dictionary: [
        "OSCAddress" : "127.0.0.1",
        "OSCPort" : 6666,
        "OSCAddrRibbon" : "/ribbon",
        "OSCAddrKnob" : "/knob",
        "OSCAddrAccel" : "/accel",
        "MIDIDevice" : -1,
        "MIDIChannel" : 1,
        "MIDICCRibbon" : 2,
        "MIDICCKnob" : 3,
        "MIDICCAccX" : 4,
        "MIDICCAccY" : 5,
        "MIDICCAccZ" : 6
        ])
    
    ////
    private var oscClient:OSCClient!
    private var oscMessage:OSCMessage!
    private var nrfManager:NRFManager!
    private var midiManager:MIDIManager!

    @IBAction func BTConnect(sender: AnyObject) {
        if self.BTStatus {
            self.nrfManager.disconnect()
        } else {
            self.scanProgress.startAnimation(nil)
            self.scanText.stringValue = "Searching for to " + nrfManager.RFDuinoName
            self.nrfManager.connect()
        }
    }
    
/*    @IBAction func about(sender: AnyObject) {
        if let checkURL = NSURL(string: "//www.spacebarman.com") {
            if NSWorkspace.sharedWorkspace().openURL(checkURL) {
                print("url successfully opened")
            }
        } else {
            print("invalid url")
        }
    }
*/  
    @IBAction func selectOutputProtocol(sender: AnyObject) {
        if OSCActive.intValue == 1 && oscClient == nil {
            midiManager = nil
            MIDIRefreshButton.enabled = false
            MIDIDevice.enabled = false
            oscClient = OSCClient()
            oscMessage = OSCMessage()
            nrfManager.dataCallback = {
                (data:NSData?, string:String?)->() in
                if let dataString = string {
                    let dataArray = dataString.characters.split{$0 == ","}.map(String.init)
                    for index in 0...(self.receivedMessages.count-1) {
                        if let value = Int(dataArray[index].stringByReplacingOccurrencesOfString("\0", withString: "")) {
                            if(value != self.prevOSCValues[index]){
                                self.oscMessage.arguments = [value]
                                self.oscMessage.address = self.receivedMessages[index]
                                self.oscClient.sendMessage(self.oscMessage, to: "udp://\(self.OSCAddress.stringValue):\(self.OSCPort.integerValue)")
                                //print("Sent \(self.OSCAddresses[index]), \(value)")
                                self.prevOSCValues[index] = value
                            }
                        }
                    }
                }
            }
            print("Using OSC")
        } else if MIDIActive.intValue == 1 && midiManager == nil {
            oscClient = nil
            oscMessage = nil
            MIDIRefreshButton.enabled = true
            MIDIDevice.enabled = true
            midiManager = MIDIManager(dev: NSUserDefaults.standardUserDefaults().integerForKey("MIDIDevice"))
            refreshMIDIDevices(0)
            nrfManager.dataCallback = {
                (data:NSData?, string:String?)->() in
                if let dataString = string {
                    let dataArray = dataString.characters.split{$0 == ","}.map(String.init)
                    for index in 0...(self.receivedMessages.count-1) {
                        if let value = Int(dataArray[index].stringByReplacingOccurrencesOfString("\0", withString: "")) {
                            let val:UInt8 = self.midiManager.mapRangeToMIDI(value,0,1023)
                            if(val != self.prevMIDIValues[index]){
                                let channel = UInt8(self.MIDIChannel.integerValue)
                                var cc:UInt8 = 1
                                switch index {
                                case 0:
                                    cc = UInt8(self.MIDICCRibbon.integerValue)
                                case 1:
                                    cc = UInt8(self.MIDICCKnob.integerValue)
                                case 2:
                                    cc = UInt8(self.MIDICCAccX.integerValue)
                                case 3:
                                    cc = UInt8(self.MIDICCAccY.integerValue)
                                case 4:
                                    cc = UInt8(self.MIDICCAccZ.integerValue)
                                default:
                                    break
                                }
                                self.midiManager.send(channel,cc,val)
                                self.prevMIDIValues[index] = val
                            }
                        }
                    }
                }
            }
            print("Using MIDI")
        } else if noneActive.intValue == 1 {
            oscClient = nil
            oscMessage = nil
            midiManager = nil
            MIDIRefreshButton.enabled = false
            MIDIDevice.enabled = false
            nrfManager.dataCallback = nil
            print("Enjoy the silence...")
        }
    }
    
    @IBAction func refreshMIDIDevices(sender: AnyObject) {
        midiManager.getMIDIDevices()
        MIDIDevice.removeAllItems()
        MIDIDevice.addItemsWithObjectValues(["BT Guitar Port"])
        MIDIDevice.addItemsWithObjectValues(midiManager.activeMIDIDeviceNames)
        MIDIDevice.selectItemAtIndex(midiManager.selectedMIDIDevice+1)
        print(MIDIDevice.objectValues)
    }
 
    @IBAction func selectMIDIDevice(sender: AnyObject) {
        if midiManager != nil {
            midiManager.setActiveMIDIDevice(MIDIDevice.indexOfSelectedItem-1)
        }
        NSUserDefaults.standardUserDefaults().setObject(midiManager.selectedMIDIDevice, forKey: "MIDIDevice")
    }
    
    @IBAction func refreshParameters(sender: AnyObject) {
        let who = sender.tag()
        switch who {
        case 0:
            NSUserDefaults.standardUserDefaults().setObject(OSCAddress.stringValue, forKey: "OSCAddress")
        case 1:
            NSUserDefaults.standardUserDefaults().setObject(OSCPort.integerValue, forKey: "OSCPort")
        case 2:
            NSUserDefaults.standardUserDefaults().setObject(OSCAddrRibbon.stringValue, forKey: "OSCAddrRibbon")
        case 3:
            NSUserDefaults.standardUserDefaults().setObject(OSCAddrKnob.stringValue, forKey: "OSCAddrKnob")
        case 4:
            NSUserDefaults.standardUserDefaults().setObject(OSCAddrAccel.stringValue, forKey: "OSCAddrAccel")
        case 5:
            NSUserDefaults.standardUserDefaults().setObject(MIDIDevice.integerValue, forKey: "MIDIDevice")
        case 6:
            NSUserDefaults.standardUserDefaults().setObject(MIDIChannel.integerValue, forKey: "MIDIChannel")
        case 7:
            NSUserDefaults.standardUserDefaults().setObject(MIDICCRibbon.integerValue, forKey: "MIDICCRibbon")
        case 8:
            NSUserDefaults.standardUserDefaults().setObject(MIDICCKnob.integerValue, forKey: "MIDICCKnob")
        case 9:
            NSUserDefaults.standardUserDefaults().setObject(MIDICCAccX.integerValue, forKey: "MIDICCAccX")
        case 10:
            NSUserDefaults.standardUserDefaults().setObject(MIDICCAccY.integerValue, forKey: "MIDICCAccY")
        case 11:
            NSUserDefaults.standardUserDefaults().setObject(MIDICCAccZ.integerValue, forKey: "MIDICCAccZ")
        default: break
        }
//        receivedMessages.removeAll()
//        receivedMessages.append(OSCAddrRibbon.stringValue)
//        receivedMessages.append(OSCAddrKnob.stringValue)
//        receivedMessages.append(OSCAddrAccel.stringValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        scanProgress.startAnimation(nil)
        receivedMessages.append(OSCAddrRibbon.stringValue)
        receivedMessages.append(OSCAddrKnob.stringValue)
        receivedMessages.append(OSCAddrAccel.stringValue)
        prevOSCValues = [0,0,0]
        prevMIDIValues = [0,0,0]
        
        nrfManager = NRFManager(
            onConnect: {
                self.BTStatus = true
                print("Connected")
                self.BTConnectText.enabled = true
                self.BTConnectText.title = "Disconnect"
                self.nrfManager.autoConnect = true
                self.BTIndicator.image = NSImage(named: "NSStatusAvailable")
                self.scanProgress.stopAnimation(nil)
                self.scanText.stringValue = "Connected to " + self.nrfManager.RFDuinoName
            },
            onDisconnect: {
                self.BTStatus = false
                print("Disconnected")
                self.BTConnectText.title = "Connect"
                self.nrfManager.autoConnect = false
                self.BTIndicator.image = NSImage(named: "NSStatusPartiallyAvailable")
                self.scanText.stringValue = "RFDuino found (not connected)"
            },
            onData: nil,
            autoConnect: true
        )
        nrfManager.verbose = false;
        scanText.stringValue = "Searching for to " + nrfManager.RFDuinoName + "..."
        BTConnectText.title = "Connecting"
        BTConnectText.enabled = false
        MIDIChannel.addItemsWithObjectValues([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])
        MIDIChannel.selectItemAtIndex(0)
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults as! [String : AnyObject])
        loadUserData()
    }
    
    func loadUserData() {
        OSCAddress.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("OSCAddress")!
        OSCPort.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("OSCPort")
        OSCAddrRibbon.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("OSCAddrRibbon")!
        OSCAddrKnob.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("OSCAddrKnob")!
        OSCAddrAccel.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("OSCAddrAccel")!
        MIDIChannel.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDIChannel")
        MIDICCRibbon.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDICCRibbon")
        MIDICCKnob.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDICCKnob")
        MIDICCAccX.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDICCAccX")
        MIDICCAccY.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDICCAccY")
        MIDICCAccZ.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDICCAccZ")
    }
    
    override func awakeFromNib() {

    }
    
}
