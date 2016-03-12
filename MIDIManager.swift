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
    private var virtualMidiClient = MIDIClientRef()
    private var virtualOutputPort = MIDIPortRef()
    private var activeMIDIDevices = [Int]()
    private let np:MIDINotifyProc = { (notification:UnsafePointer<MIDINotification>, refcon:UnsafeMutablePointer<Void>) in
    }
    private var destination:MIDIEndpointRef = MIDIEndpointRef()
    private(set) public var selectedMIDIDevice = Int()
    public var activeMIDIDeviceNames = [String]()
    
    public init(thing:Bool = true) {
        super.init()
        getMIDIDevices()
        // -1 is the virtual MIDI port
        setActiveMIDIDevice(-1)
        selectedMIDIDevice = -1
    }
    
    public func setActiveMIDIDevice(index:Int)
    {
        var status = OSStatus(noErr)
        if index >= 0 {
//            MIDIClientDispose(virtualMidiClient)
            status = MIDIClientCreate("MIDIClient", np, nil, &midiClient)
            status = MIDIOutputPortCreate(midiClient, "Output", &outputPort);
            destination = MIDIGetDestination(index)
        } else {
//            MIDIClientDispose(midiClient)
            var status = OSStatus(noErr)
            status = MIDIClientCreate("VirtualMIDIClient", np, nil, &virtualMidiClient)
            status = MIDIOutputPortCreate(virtualMidiClient, "Output2", &virtualOutputPort);
            MIDISourceCreate(virtualMidiClient, "BT Guitar Port", &virtualOutputPort);
        }
        selectedMIDIDevice = index
    }
    
    public func getMIDIDevices() {
        activeMIDIDeviceNames.removeAll()
        activeMIDIDevices.removeAll()
        // Include:
        //MIDIGetNumberOfDestinations()
        //MIDIGetDestination()
        for i in 0...MIDIGetNumberOfDevices()-1 {
            let dev:MIDIDeviceRef = MIDIGetDevice(i)
            var props: Unmanaged<CFPropertyList>?
            _ = MIDIObjectGetProperties(dev, &props, true)
            if let midiProperties: CFPropertyList = props?.takeUnretainedValue() {
                let midiDictionary = midiProperties as! NSDictionary
                if midiDictionary["offline"] !== 1 {
                    if midiDictionary["entities"]!.count != 0 {
                        if let entities = midiDictionary["entities"] {
                            for entity in entities as! NSArray {
                                //print(entity)
                                if entity["destinations"]!!.count > 0 {
                                    if entity["offline"]! == nil {
                                        activeMIDIDeviceNames.append(entity["name"] as! String)
                                        activeMIDIDevices.append(entity["uniqueID"] as! Int)
                                    } else {
                                        let offline = entity["offline"] as! Int
                                        if offline != 1 {
                                            activeMIDIDeviceNames.append(entity["name"] as! String)
                                            activeMIDIDevices.append(entity["uniqueID"] as! Int)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                print("Couldn't load properties for \(index)")
            }
        }
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
        var packet:MIDIPacket = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        //packet.data.0 = 0xB0 + MIDIchannel // Controller and channel number
        packet.data.0 = UInt8(176) + MIDIChannel-1 // Controller + channel number
        packet.data.1 = MIDIControl // Control number
        packet.data.2 = MIDIControlValue // Control value

        var packetList:MIDIPacketList = MIDIPacketList(numPackets: 1, packet: packet);

        if selectedMIDIDevice < 0 {
            return MIDIReceived(virtualOutputPort, &packetList)
        }
        else {
            return MIDISend(outputPort, destination, &packetList)
        }
    }
    
    func mapRangeToMIDI(input: Int, _ input_lowest: Int, _ input_highest: Int) ->UInt8{
        return UInt8((127 / (float_t(input_highest) - float_t(input_lowest))) * (float_t(input) - float_t(input_lowest)))
    }
    
}