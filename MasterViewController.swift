//
//  MasterViewController.swift
//  BT Guitar Interface
//
//  Created by JP Carrascal on 05/03/16.
//  Copyright © 2016 Spacebarman. All rights reserved.
//

import Cocoa
import OSCKit
import MIKMIDI
import IOBluetooth

////class MasterViewController: NSViewController {
class MasterViewController: NSViewController, NRFManagerDelegate {

    @IBOutlet weak var outputSelect: NSTabViewItem!
    @IBOutlet weak var scanProgress: NSProgressIndicator!
    @IBOutlet weak var scanText: NSTextField!
    @IBOutlet weak var BTConnectText: NSButton!
    @IBOutlet weak var BTIndicator: NSImageView!
    @IBOutlet weak var OSCActive: NSButton!
    @IBOutlet weak var OSCAddress: NSTextField!
    @IBOutlet weak var OSCPort: NSTextField!
    @IBOutlet weak var OSCAddrRibbon: NSTextField!
    @IBOutlet weak var OSCAddrKnob: NSTextField!
    @IBOutlet weak var OSCAddrAccel: NSTextField!
    @IBOutlet weak var MIDIDevice: NSComboBox!
    @IBOutlet weak var MIDIChannel: NSComboBox!
    @IBOutlet weak var MIDICCRibbon: NSTextField!
    @IBOutlet weak var MIDICCKnob: NSTextField!
    @IBOutlet weak var MIDICCAccX: NSTextField!
    @IBOutlet weak var MIDICCAccY: NSTextField!
    @IBOutlet weak var MIDICCAccZ: NSTextField!
    
    private let client = OSCClient()
//    private let server = OSCServer()
    private let message = OSCMessage()
    private var OSCAddresses = [String]()
    private var serverAddress:String = ""
    private var serverPort:Int = 0
    private var prevValues = [Int]()
    private var availableDevices = MIKMIDIDeviceManager.sharedDeviceManager().availableDevices
    private var deviceListNames = [String]()
    private var BTStatus = false;

    
    ////
    var nrfManager:NRFManager!

    @IBAction func BTConnect(sender: AnyObject) {
        if self.BTStatus {
            self.nrfManager.disconnect()
        } else {
            self.scanProgress.startAnimation(nil)
            self.scanText.stringValue = "Connecting to RFDuino"
            self.nrfManager.connect()
        }
    }
    
    @IBAction func selectOutputProtocol(sender: AnyObject) {
        if OSCActive.intValue == 1 {
            nrfManager.dataCallback = {
                (data:NSData?, string:String?)->() in
                //print("Recieved data - String: \(string) - Data: \(data)")
                if let dataString = string {
                    let dataArray = dataString.characters.split{$0 == ","}.map(String.init)
                    for index in 0...(self.OSCAddresses.count-1) {
                        if let value = Int(dataArray[index].stringByReplacingOccurrencesOfString("\0", withString: "")) {
                            if(value != self.prevValues[index]){
                                self.message.arguments = [value]
                                self.message.address = self.OSCAddresses[index]
                                self.client.sendMessage(self.message, to: "udp://\(self.serverAddress):\(self.serverPort)")
                                //print("Sent \(self.OSCAddresses[index]), \(value)")
                                self.prevValues[index] = value
                            }
                        }
                    }
                }
            }
            print("Using OSC")
        } else {
            nrfManager.dataCallback = {
                (data:NSData?, string:String?)->() in
                //print("Recieved data - String: \(string) - Data: \(data)")
                if let dataString = string {
                    let dataArray = dataString.characters.split{$0 == ","}.map(String.init)
                    for index in 0...(self.OSCAddresses.count-1) {
                        if let value = Int(dataArray[index].stringByReplacingOccurrencesOfString("\0", withString: "")) {
                            if(value != self.prevValues[index]){
                                //print("Sending MIDI")
                                self.prevValues[index] = value
                            }
                        }
                    }
                }
            }
            print("Using MIDI")
        }
    }
    
    @IBAction func refreshMIDIDevices(sender: AnyObject) {
        deviceListNames.removeAll()
        availableDevices = MIKMIDIDeviceManager.sharedDeviceManager().availableDevices
        for device in availableDevices {
            if(device.entities.count > 0){
                for entity in device.entities {
                    if(entity.destinations.count > 0) {
                        for destination in entity.destinations {
                            deviceListNames.append(destination.name!)
                        }
                    }
                }
            }
        }
        print(deviceListNames)
        MIDIDevice.removeAllItems()
        MIDIDevice.addItemsWithObjectValues(deviceListNames)
        MIDIDevice.selectItemAtIndex(0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        ////
        scanProgress.startAnimation(nil)
        
        serverAddress = OSCAddress.stringValue
        serverPort = OSCPort.integerValue
        OSCAddresses.append(OSCAddrRibbon.stringValue)
        OSCAddresses.append(OSCAddrKnob.stringValue)
        OSCAddresses.append(OSCAddrAccel.stringValue)
        prevValues = [0,0,0]
        
        BTConnectText.title = "Connecting"
        BTConnectText.enabled = false
        
        nrfManager = NRFManager(
            onConnect: {
                self.BTStatus = true
                print("Connected")
                self.BTConnectText.enabled = true
                self.BTConnectText.title = "Disconnect"
                self.nrfManager.autoConnect = true
                self.BTIndicator.image = NSImage(named: "NSStatusAvailable")
                self.scanProgress.stopAnimation(nil)
                self.scanText.stringValue = "Connected to RFDuino"
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
        
        //nrfManager.dataCallback = OSCFunction
        nrfManager.verbose = false;
        print(OSCAddress.stringValue)
        print(OSCPort.stringValue)
        refreshMIDIDevices(0)
        
        MIDIChannel.addItemsWithObjectValues([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])
        MIDIChannel.selectItemAtIndex(0)
    }
    
    override func awakeFromNib() {

    }

}
