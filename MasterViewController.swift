//
//  MasterViewController.swift
//  BlueMO
//
//  Created by JP Carrascal on 05/03/16.
//  Copyright © 2016 Spacebarman. All rights reserved.
//

import Cocoa
import OSCKit
import IOBluetooth

class MasterViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

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
    
    private var outputSelect: String = "None"
    private var dataBuffer = [String]()/* {
        didSet {
            print(dataBuffer.count)
            while dataBuffer.count > 0 {
                sendData(dataBuffer[0])
                dataBuffer.removeAtIndex(0)
            }
        }
    }*/
    private var inputDataCount: Int = 0
    private var mappings = [[String : String]]()
    private var prevOSCValues = [Int]()
    private var prevMIDIValues = [UInt8]()
    private var deviceListNames = [String]()
    private var BTStatus = false;
    private var defaults = NSDictionary(dictionary: [
        "deviceName" : "Bluefruit LE",
        "outputSelect" : "None",
        "OSCAddress" : "127.0.0.1",
        "OSCPort" : 6666,
        "MIDIDevice" : 0,
        "MIDIChannel" : 1,
        "Mappings" : [["msgAddress": "/a", "position": "1", "cc": "1", "activity": "0:0"], ["msgAddress": "/b", "position": "2", "cc": "2", "activity": "0:0"], ["msgAddress": "/c", "position": "3", "cc": "3", "activity": "0:0"]]
        ])
    
    private var oscClient:OSCClient!
    private var oscMessage:OSCMessage!
    private var nrfManager:NRFManager!
    private var midiManager:MIDIManager!
    private let saveTableNotificationKey = "com.spacebarman.btcontroller.save"

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
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("ccCol")].hidden = true
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("msgAddressCol")].hidden = false
            nrfManager.dataCallback = {
                (data:NSData?, string:String?)->() in
                if let incomingString = string {
                    print(incomingString)
                    self.sendData(incomingString)
                    // Append incoming data to buffer (Currently unused)
                    //self.dataBuffer.append(incomingString)
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
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("msgAddressCol")].hidden = true
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("ccCol")].hidden = false
            nrfManager.dataCallback = {
                (data:NSData?, string:String?)->() in
                if let incomingString = string {
                    self.sendData(incomingString)
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
            outputSelect = "None"
            clearLeds()
            print("Enjoy the silence...")
            NSUserDefaults.standardUserDefaults().setObject(outputSelect, forKey: "outputSelect")
        }
        mappingTableView.reloadData()
    }
    
    /*  Function for consuming a buffer made of incoming Bluetooth data (currently unused)
        Apple limits the connection interval, as explained in:
        https://developer.apple.com/hardwaredrivers/BluetoothDesignGuidelines.pdf
        If the peripheral sends at shorter intervals (shorter than 100ms, according to my observations,
        but apparently 0x54 = 105ms)
        packages start to get bundled together.*
        My initial attempt to solve this was by appending all incoming data to valuesBuffer,
        and then send a notification to this function for it to consume the data.
        This works, but introduces a delay :(
        I think this can still work, but I need to make the consumption triggered
        not by an incoming data notification, but independently (and fast!).

        * According to that same document, the connection interval cannot be changed,
        but can be requested by the peripheral by means of a L2CAP Connection Parameter Update Request.
        (I don't know if that can be done with Bluefruit or RFDuino)
        Some keywords to Google about:
        bluetooth LE os x connection interval 0x54 105ms L2CAP CBCentralManager
    */
    func consumeInputBuffer()//sender:AnyObject)
    {
        while dataBuffer.count > 0 {
            sendData(dataBuffer[0])
            dataBuffer.removeAtIndex(0)
        }
    }
    
    func sendData(incomingString: String) {
        let incomingArray = incomingString.characters.split{$0 == ","}.map(String.init)
        if inputDataCount != incomingArray.count {
            mappings.removeAll()
            inputDataCount = incomingArray.count
            updateMappings(inputDataCount)
            prevOSCValues.removeAll()
            prevMIDIValues.removeAll()
            for _ in 0..<incomingArray.count {
                prevOSCValues.append(0)
                prevMIDIValues.append(0)
            }
        }
        if incomingArray.count > 0 {
            for index in 0..<incomingArray.count {
                if let value = Int(incomingArray[index].stringByReplacingOccurrencesOfString("\0", withString: ""), radix: 16) {
                    if outputSelect == "OSC" {
                        if(value != prevOSCValues[index]){
                            activityLed(index, true, value)
                            oscMessage.arguments = [value]
                            oscMessage.address = mappings[index]["msgAddress"]!
                            oscClient.sendMessage(oscMessage, to: "udp://\(self.OSCAddress.stringValue):\(self.OSCPort.integerValue)")
                            prevOSCValues[index] = value
                        } else {
                            activityLed(index, false, value)
                        }
                    } else if outputSelect == "MIDI" {
                        let val:UInt8 = midiManager.mapRangeToMIDI(value,0,1023)
                        if(val != prevMIDIValues[index]){
                            activityLed(index, true, Int(val))
                            let channel = UInt8(MIDIChannel.integerValue)
                            let cc = UInt8(mappings[index]["cc"]!)
                            midiManager.send(channel,cc!,val)
                            prevMIDIValues[index] = val
                        } else {
                            activityLed(index, false, Int(val))
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func refreshMIDIDevices(sender: AnyObject) {
        midiManager.getMIDIDevices()
        MIDIDevice.removeAllItems()
        MIDIDevice.addItemsWithObjectValues(["BlueMO port"])
        MIDIDevice.addItemsWithObjectValues(midiManager.activeMIDIDeviceNames)
        MIDIDevice.selectItemAtIndex(midiManager.selectedMIDIDevice+1)
        print("Detected MIDI devices: \(MIDIDevice.objectValues)")
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
            clearLeds()
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
            NSUserDefaults.standardUserDefaults().setObject(MIDIChannel.indexOfSelectedItem, forKey: "MIDIChannel")
        default:
            NSUserDefaults.standardUserDefaults().setObject(mappings, forKey: "Mappings")
        }
    }
    
    func saveTable(sender:AnyObject) {
        let cellData = sender.object as! NSDictionary
        let tmp = cellData["row"] as! String
        let row = Int(tmp)!
        let col:String = cellData["col"] as! String
        let val:String = cellData["val"] as! String
        mappings[row][col] = val
        mappingTableView.reloadData()
        NSUserDefaults.standardUserDefaults().setObject(mappings, forKey: "Mappings")
        print("Table saved.")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        scanProgress.startAnimation(nil)
        prevOSCValues = [0,0,0,0,0,0,0,0]
        prevMIDIValues = [0,0,0,0,0,0,0,0]
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults as! [String : AnyObject])
        MIDIChannel.addItemsWithObjectValues([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])
        loadUserData()
        if outputSelect == "OSC" {
            OSCActive.intValue = 1
            outputTabBar.selectFirstTabViewItem(0)
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("ccCol")].hidden = true
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("msgAddressCol")].hidden = false
        } else if outputSelect == "MIDI" {
            MIDIActive.intValue = 1
            outputTabBar.selectLastTabViewItem(0)
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("msgAddressCol")].hidden = true
            mappingTableView.tableColumns[mappingTableView.columnWithIdentifier("ccCol")].hidden = false
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
                self.clearLeds()
                self.BTConnectText.title = "Connect"
                self.nrfManager.autoConnect = false
                self.BTIndicator.image = NSImage(named: "NSStatusNone")
                self.scanText.stringValue = "Not connected"
            },
            onData: nil,
            deviceName: deviceName.stringValue,
            autoConnect: true
        )
        nrfManager.verbose = false;
        scanText.stringValue = "Searching for " + nrfManager.deviceName + "..."
        BTConnectText.title = "Connecting"
        BTConnectText.enabled = false
        selectOutputProtocol(0)
//        flushNSUserDefaults()
        updateMappings(3)
        mappingTableView.setDelegate(self)
        mappingTableView.setDataSource(self)
        mappingTableView.target = self
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(saveTable), name: saveTableNotificationKey, object: nil)
    }
    
    func loadUserData() {
        outputSelect = NSUserDefaults.standardUserDefaults().stringForKey("outputSelect")!
        deviceName.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("deviceName")!
        OSCAddress.stringValue = NSUserDefaults.standardUserDefaults().stringForKey("OSCAddress")!
        OSCPort.integerValue = NSUserDefaults.standardUserDefaults().integerForKey("OSCPort")
        // MIDI port is not here as it is recovered after scan
        MIDIChannel.selectItemAtIndex(NSUserDefaults.standardUserDefaults().integerForKey("MIDIChannel"))
    }


    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var image:NSImage?
        var text:String = ""
        var cellIdentifier: String = ""
        let item = mappings[row]
        if tableColumn == tableView.tableColumns[0] {
            if let activity = item["activity"] {
                let activityArr = activity.characters.split{$0 == ":"}.map(String.init)
                if activityArr[0] == "1" {
                    image = NSImage(named: "NSStatusAvailable")
                } else {
                    image = NSImage(named: "NSStatusNone")
                }
                if activityArr.count > 1 {
                    //image?.size = NSSize(width: Int(activityArr[1])!, height: 17)
                    text = activityArr[1]
                }
            }
            cellIdentifier = "activity"
        } else if tableColumn == tableView.tableColumns[1] {
            text = item["position"]!
            cellIdentifier = "position"
        } else if tableColumn == tableView.tableColumns[2] {
            text = item["msgAddress"]!
            cellIdentifier = "msgAddress"
        } else if tableColumn == tableView.tableColumns[3] {
            text = item["cc"]!
            cellIdentifier = "cc"
        }
        if let cell = tableView.makeViewWithIdentifier(cellIdentifier, owner: nil) as? NSTableCellView {
            cell.imageView?.image = image ?? nil
            cell.textField?.stringValue = text
            cell.textField?.tag = row
            return cell
        }
        return nil
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return mappings.count ?? 0
    }

    func updateMappings(incomingCount: Int) {
        mappings = (NSUserDefaults.standardUserDefaults().objectForKey("Mappings") as? [[String: String]])!
        // If more messages are received, pad the mappings table with empty rows:
        if incomingCount > mappings.count {
            var maxcc = 1
            for item in mappings {
                let curcc = Int(item["cc"]!)
                if  curcc > maxcc {
                    maxcc = curcc!
                }
            }
            let mapcount = mappings.count
            for i in mapcount..<incomingCount {
                let data = ["position": String(i+1), "msgAddress":"/",
                    "cc":String(maxcc+i-mapcount+1), "activity": "0:0"]
                mappings.append(data)
            }
        } else {
        // ... or if less messages are received, remove the unused ones
            mappings.removeRange(Range<Int>(incomingCount ..< mappings.count))
        }
        mappingTableView.reloadData()
    }
    
    func activityLed(index:Int, _ status:Bool, _ value: Int) {
        if status {
            self.mappings[index]["activity"] = "1:"+String(value)
        } else {
            self.mappings[index]["activity"] = "0:"+String(value)
        }
        self.mappingTableView.beginUpdates()
        self.mappingTableView.reloadDataForRowIndexes(NSIndexSet(index: index), columnIndexes: NSIndexSet(index: 0))
        self.mappingTableView.endUpdates()
    }
    
    func clearLeds()
    {
        if mappings.count > 0 {
            for i in 0..<mappings.count {
                activityLed(i, false, 0)
            }
        }
    }
    
    // Handy function, as sometimes it is hard to get rid of some sticky values
    func flushNSUserDefaults()
    {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "justAnotherKey1")
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "justAnotherKey2")
        for key in Array(NSUserDefaults.standardUserDefaults().dictionaryRepresentation().keys) {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(key)
        }
    }
    
}



class TableTextField:NSTextField, NSTextFieldDelegate {
private let saveTableNotificationKey = "com.spacebarman.btcontroller.save"

    override func awakeFromNib() {
    delegate = self
    }

    override func textDidEndEditing(obj: NSNotification)
    {
        let col = self.superview!.identifier
        let row = String(self.tag)
        let val = self.stringValue
        let cellData: NSDictionary = [ "row" : row, "col" : col!, "val" : val]
        NSNotificationCenter.defaultCenter().postNotificationName(saveTableNotificationKey, object: cellData)
    }
}

