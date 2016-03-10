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
    public var activeMIDIDevices = [Int]()
    public var activeMIDIDeviceNames = [String]()
    
    public init(thing:Bool = true) {
        super.init()
        var status = OSStatus(noErr)
        
        let np:MIDINotifyProc = { (notification:UnsafePointer<MIDINotification>, refcon:UnsafeMutablePointer<Void>) in
        }
        
        status = MIDIClientCreate("MyMIDIClient", np, nil, &midiClient)
        status = MIDIOutputPortCreate(midiClient, "Output", &outputPort);
        if status != OSStatus(noErr){
            print("Somthing wrong happened")
        }
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
    }

    public func send() {
        var endPoint = MIDIObjectRef()
        var foundObj = MIDIObjectType.Destination
        
        _ = MIDIObjectFindByUniqueID(0, &endPoint, &foundObj)

        var pkt = UnsafeMutablePointer<MIDIPacket>.alloc(1)
        let pktList = UnsafeMutablePointer<MIDIPacketList>.alloc(1)
        let midiData : [UInt8] = [UInt8(144), UInt8(36), UInt8(5)]
        pkt = MIDIPacketListInit(pktList)
        pkt = MIDIPacketListAdd(pktList, 1024, pkt, 0, 3, midiData)

        MIDISend(outputPort, endPoint, pktList)

/*
        let pushDevice = MIDIGetDevice(0)
        print("I'm sending... in theory")
        
        let secondEntity = MIDIDeviceGetEntity(pushDevice, 1)
        
        let pushDestination = MIDIEntityGetDestination(secondEntity, 0)
        
        let myData : [UInt8] = [ UInt8(144), UInt8(36), UInt8(5) ]
        var packet = UnsafeMutablePointer<MIDIPacket>.alloc(1)
        let pkList = UnsafeMutablePointer<MIDIPacketList>.alloc(1)
        packet = MIDIPacketListInit(pkList)
        packet = MIDIPacketListAdd(pkList, 1024, packet, 0, 3, myData)
        
        MIDISend(outputPort, pushDestination, pkList)
*/
    }
    
}