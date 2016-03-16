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
class MasterViewController: NSViewController, NRFManagerDelegate, NSTableViewDelegate {

    @IBOutlet weak var deviceName: NSTextField!
    @IBOutlet weak var outputTabBar: NSTabView!
    @IBOutlet weak var scanProgress: NSProgressIndicator!
    @IBOutlet weak var scanText: NSTextField!
    @IBOutlet weak var BTConnectText: NSButton!
    @IBOutlet weak var BTIndicator: NSImageView!
    @IBOutlet weak var OSCActive: NSButton!
    @IBOutlet weak var MIDIActive: NSButton!
    @IBOutlet weak var noneActive: NSButton!
    @IBOutlet weak var OSCAddress: NSTextField!
    @IBOutlet weak var OSCPort: NSTextField!
    
    @IBOutlet weak var mappingTableView: NSTableView!
    
    @IBOutlet weak var MIDIRefreshButton: NSButton!
    @IBOutlet weak var MIDIDevice: NSComboBox!
    @IBOutlet weak var MIDIChannel: NSComboBox!
    
    private var outputSelect: String = ""
    private var inputDataCount: Int = 0
    private var mappings = [[String : String]]()
    private var prevOSCValues = [Int]()
    private var prevMIDIValues = [UInt8]()
    private var deviceListNames = [String]()
    private var BTStatus = false;
    private var defaults = NSDictionary(dictionary: [
        "deviceName" : "RFDuino",
        "outputSelect" : "None",
        "OSCAddress" : "127.0.0.1",
        "OSCPort" : 6666,
        "MIDIDevice" : -1,
        "MIDIChannel" : 1,
        "Mappings" : [["msgAddress": "/a", "Position": "1", "cc": "1", "status": "0"], ["msgAddress": "/b", "Position": "2", "cc": "2", "status": "0"], ["msgAddress": "/c", "Position": "3", "cc": "3", "status": "0"]]
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
            self.scanText.stringValue = "Searching for to " + nrfManager.deviceName
            self.nrfManager.connect()
        }
    }

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
                    if self.inputDataCount != dataArray.count {
                        self.mappings.removeAll()
                        self.inputDataCount = dataArray.count
                        self.updateMappings(self.inputDataCount)
                        self.prevOSCValues.removeAll()
                        for _ in 0...(dataArray.count-1) {
                            self.prevOSCValues.append(0)
                        }
                    }
                    for index in 0...(dataArray.count-1) {
                        if let value = Int(dataArray[index].stringByReplacingOccurrencesOfString("\0", withString: "")) {
                            if(value != self.prevOSCValues[index]){
                                self.activityLed(index, true)
                                self.oscMessage.arguments = [value]
                                self.oscMessage.address = self.mappings[index]["msgAddress"]!
                                self.oscClient.sendMessage(self.oscMessage, to: "udp://\(self.OSCAddress.stringValue):\(self.OSCPort.integerValue)")
                                self.prevOSCValues[index] = value
                            } else {
                                self.activityLed(index, false)
                            }
                        }
                    }
                }
            }
            print("Using OSC")
            outputTabBar.selectFirstTabViewItem(0)
            outputSelect = "OSC"
            NSUserDefaults.standardUserDefaults().setObject(outputSelect, forKey: "outputSelect")
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
                    if self.inputDataCount != dataArray.count {
                        self.inputDataCount = dataArray.count
                        self.updateMappings(self.inputDataCount)
                        self.prevMIDIValues.removeAll()
                        for _ in 0...(dataArray.count-1) {
                            self.prevMIDIValues.append(0)
                        }
                    }
                    for index in 0...(dataArray.count-1) {
                        if let value = Int(dataArray[index].stringByReplacingOccurrencesOfString("\0", withString: "")) {
                            let val:UInt8 = self.midiManager.mapRangeToMIDI(value,0,1023)
                            if(val != self.prevMIDIValues[index]){
                                self.activityLed(index, true)
                                let channel = UInt8(self.MIDIChannel.integerValue)
                                let cc = UInt8(self.mappings[index]["cc"]!)
                                self.midiManager.send(channel,cc!,val)
                                self.prevMIDIValues[index] = val
                            } else {
                                self.activityLed(index, false)
                            }
                        }
                    }
                }
            }
            print("Using MIDI")
            outputTabBar.selectLastTabViewItem(0)
            outputSelect = "MIDI"
            NSUserDefaults.standardUserDefaults().setObject(outputSelect, forKey: "outputSelect")
        } else if noneActive.intValue == 1 {
            oscClient = nil
            oscMessage = nil
            midiManager = nil
            MIDIRefreshButton.enabled = false
            MIDIDevice.enabled = false
            nrfManager.dataCallback = nil
            print("Enjoy the silence...")
            outputSelect = "None"
            NSUserDefaults.standardUserDefaults().setObject(outputSelect, forKey: "outputSelect")
        }
        mappingTableView.reloadData()
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
            nrfManager.deviceName = deviceName.stringValue
            self.nrfManager.disconnect()
            scanText.stringValue = "Searching for " + nrfManager.deviceName + "..."
            self.nrfManager.connect()
            NSUserDefaults.standardUserDefaults().setObject(deviceName.stringValue, forKey: "deviceName")
        case 1:
            NSUserDefaults.standardUserDefaults().setObject(OSCAddress.stringValue, forKey: "OSCAddress")
        case 2:
            NSUserDefaults.standardUserDefaults().setObject(OSCPort.integerValue, forKey: "OSCPort")
        case 3:
            NSUserDefaults.standardUserDefaults().setObject(MIDIDevice.integerValue, forKey: "MIDIDevice")
        case 4:
            NSUserDefaults.standardUserDefaults().setObject(MIDIChannel.integerValue, forKey: "MIDIChannel")
        default:
            NSUserDefaults.standardUserDefaults().setObject(mappings, forKey: "Mappings")
        }
// Fix this:
        NSUserDefaults.standardUserDefaults().setObject(mappings, forKey: "Mappings")
        //print(NSUserDefaults.standardUserDefaults().arrayForKey("Mappings"))

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        scanProgress.startAnimation(nil)
        prevOSCValues = [0,0,0,0,0,0,0,0]
        prevMIDIValues = [0,0,0,0,0,0,0,0]
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults as! [String : AnyObject])
        loadUserData()
        if outputSelect == "OSC" {
            OSCActive.intValue = 1
            outputTabBar.selectFirstTabViewItem(0)
        } else if outputSelect == "MIDI" {
            MIDIActive.intValue = 1
            outputTabBar.selectLastTabViewItem(0)
        } else {
            noneActive.intValue = 1
            outputTabBar.selectFirstTabViewItem(0)
        }
        
        nrfManager = NRFManager(
            onConnect: {
                self.BTStatus = true
                print("Connected")
                self.BTConnectText.enabled = true
                self.BTConnectText.title = "Disconnect"
                self.nrfManager.autoConnect = true
                self.BTIndicator.image = NSImage(named: "NSStatusAvailable")
                self.scanProgress.stopAnimation(nil)
                self.scanText.stringValue = "Connected to " + self.nrfManager.deviceName
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
            deviceName: deviceName.stringValue,
            autoConnect: true
        )
        nrfManager.verbose = false;
        scanText.stringValue = "Searching for " + nrfManager.deviceName + "..."
        BTConnectText.title = "Connecting"
        BTConnectText.enabled = false
        MIDIChannel.addItemsWithObjectValues([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])
        MIDIChannel.selectItemAtIndex(0)
        selectOutputProtocol(0)
        updateMappings(3)
        mappingTableView.setDelegate(self)
        mappingTableView.setDataSource(self)
    }
    
    func loadUserData() {
        outputSelect = NSUserDefaults.standardUserDefaults().stringForKey("outputSelect")!
        deviceName.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("deviceName")!
        OSCAddress.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("OSCAddress")!
        OSCPort.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("OSCPort")
        // MIDI port is not here as it is recovered after scan
        MIDIChannel.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("MIDIChannel")
    }


    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var image:NSImage?
        var text:String = ""
        var cellIdentifier: String = ""
        // 1
        let item = mappings[row]
        if tableColumn == tableView.tableColumns[0] {
            if item["status"] == "0" {
                image = NSImage(named: "NSStatusNone")
            } else {
                image = NSImage(named: "NSStatusAvailable")
            }
            cellIdentifier = "activityCellID"
        } else if tableColumn == tableView.tableColumns[1] {
            text = item["Position"]!
            cellIdentifier = "positionCellID"
        } else if tableColumn == tableView.tableColumns[2] {
            if outputSelect == "OSC" {
                text = item["msgAddress"]!
            } else if outputSelect == "MIDI" {
                text = item["cc"]!
            }
            cellIdentifier = "destinationCellID"
        }
        // 3
        if let cell = tableView.makeViewWithIdentifier(cellIdentifier, owner: nil) as? NSTableCellView {
            cell.imageView?.image = image ?? nil
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
    

    func updateMappings(datacount: Int) {
        mappings = (NSUserDefaults.standardUserDefaults().objectForKey("Mappings") as? [[String: String]])!
        // If more messages are received, pad the mappings table with empty rows:
        if datacount > mappings.count {
            var maxcc = 1
            for item in mappings {
                let curcc = Int(item["cc"]!)
                if  curcc > maxcc {
                    maxcc = curcc!
                }
            }
            let mapcount = mappings.count
            for i in mapcount...(datacount-1) {
                let data = ["Position": String(i+1), "msgAddress":"",
                    "cc":String(maxcc+i-mapcount+1), "status": "0"]
                mappings.append(data)
            }
        }
//        print(mappings)
        mappingTableView.reloadData()
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        var mySelectedRows = [Int]()
        let myTableViewFromNotification = notification.object as! NSTableView
        // In this example, the TableView allows multiple selection
        let indexes = myTableViewFromNotification.selectedRowIndexes
        var index = indexes.firstIndex
        while index != NSNotFound {
            mySelectedRows.append(index)
            index = indexes.indexGreaterThanIndex(index)
        }
        print(mySelectedRows)
    }
    
    func activityLed(index:Int, _ status:Bool) {
        if status {
            self.mappings[index]["status"] = "1"
        } else {
            self.mappings[index]["status"] = "0"
        }
        self.mappingTableView.beginUpdates()
        self.mappingTableView.reloadDataForRowIndexes(NSIndexSet(index: index), columnIndexes: NSIndexSet(index: 0))
        self.mappingTableView.endUpdates()
    }
    
    
}

extension MasterViewController : NSTableViewDataSource {
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        //return directoryItems?.count ?? 0
        return mappings.count
    }
}
