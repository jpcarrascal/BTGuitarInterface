//
//  MIDIManager.swift
//  BT Guitar Interface
//
//  Created by JP Carrascal on 09/03/16.
//  Copyright © 2016 Spacebarman. All rights reserved.
//

import Foundation
import CoreMIDI

public class MIDIManager:NSObject {

    private var midiClient = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var activeMIDIDevices = [Int]()
    public var activeMIDIDeviceNames = [String]()
    public var selectedMIDIDevice = Int()
    
    public init(thing:Bool = true) {
        super.init()
        var status = OSStatus(noErr)
        let np:MIDINotifyProc = { (notification:UnsafePointer<MIDINotification>, refcon:UnsafeMutablePointer<Void>) in
        }
        status = MIDIClientCreate("MyMIDIClient", np, nil, &midiClient)
        status = MIDIOutputPortCreate(midiClient, "Output", &outputPort);
        if status != OSStatus(noErr){
            print("Error initializing MIDIManager")
        }
        getActiveMIDIDevices()
        selectedMIDIDevice = 0
    }
    
    public func getActiveMIDIDevices() {
        activeMIDIDeviceNames.removeAll()
        activeMIDIDevices.removeAll()
        //MIDIGetDevice returns a MIDIDeviceRef, which is an alias of MIDIObjectRef, and both are UINt32
        for i in 0...MIDIGetNumberOfDevices()-1 {
            let dev:MIDIDeviceRef = MIDIGetDevice(i)
            var props: Unmanaged<CFPropertyList>?
            _ = MIDIObjectGetProperties(dev, &props, true)
            if let midiProperties: CFPropertyList = props?.takeUnretainedValue() {
                let midiDictionary = midiProperties as! NSDictionary
                if midiDictionary["offline"] !== 1 {
                    if midiDictionary["entities"]!.count != 0 {
                        let entities = midiDictionary["entities"]!
                        for entity in entities as! [AnyObject] {
                            if entity["destinations"]!!.count > 0 {
                                activeMIDIDeviceNames.append(entity["name"] as! String)
                                activeMIDIDevices.append(entity["uniqueID"] as! Int)
                            }
                        }
                    }
                }
            } else {
                print("Couldn't load properties for \(index)")
            }
        }
        print(activeMIDIDeviceNames)
        print(activeMIDIDevices)
    }

    public func send(MIDIChannel: UInt8, _ MIDIControl: UInt8, _ MIDIControlValue: UInt8) ->OSStatus {
/*
        // Maybe this block works for iOS?
        var status = OSStatus(noErr)
        var endPoint = MIDIObjectRef()
        var foundObj = MIDIObjectType.Destination
        status = MIDIObjectFindByUniqueID(Int32(activeMIDIDevices[selectedMIDIDevice]), &endPoint, &foundObj)
        var pkt = UnsafeMutablePointer<MIDIPacket>.alloc(1)
        let pktList = UnsafeMutablePointer<MIDIPacketList>.alloc(1)
        let midiData : [UInt8] = [UInt8(144), UInt8(36), UInt8(5)]
        pkt = MIDIPacketListInit(pktList)
        pkt = MIDIPacketListAdd(pktList, sizeof(pktList.dynamicType), pkt, 0, midiData.count, midiData)
        MIDISend(outputPort, endPoint, pktList)
*/
        let dest:MIDIEndpointRef = MIDIGetDestination(selectedMIDIDevice)
        var packet:MIDIPacket = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        //packet.data.0 = 0xB0 + MIDIchannel // Controller and channel number
        packet.data.0 = UInt8(176) + MIDIChannel-1 // Controller + channel number
        packet.data.1 = MIDIControl // Control number
        packet.data.2 = MIDIControlValue // Control value

        var packetList:MIDIPacketList = MIDIPacketList(numPackets: 1, packet: packet);
        
        return MIDISend(outputPort, dest, &packetList)
    }
    
    func mapRangeToMIDI(input: Int, _ input_lowest: Int, _ input_highest: Int) ->UInt8{
        return UInt8((127 / (float_t(input_highest) - float_t(input_lowest))) * (float_t(input) - float_t(input_lowest)))
    }
    
}