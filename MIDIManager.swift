//
//  MIDIManager.swift
//  BT Guitar Interface
//
//  Created by JP Carrascal on 09/03/16.
//  Copyright © 2016 Spacebarman. All rights reserved.
//
// NOTE1:
// Properties shoud be obtained with MIDIObjectGetIntegerProperty() and MIDIObjectGetStringProperty(),
// but MIDIObjectGetStringProperty() is a mess in OSX
// Check:
// http://stackoverflow.com/questions/27169807/swift-unsafemutablepointerunmanagedcfstring-allocation-and-print
// And the solution was here:
// http://qiku.es/pregunta/78314/necesitas-ayuda-conversi%C3%B3n-cfpropertylistref-nsdictionary-a-swift-need-help-converting-cfpropertylistref-nsdictionary-to-swift


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
        for i in 0...MIDIGetNumberOfDevices()-1 {
            let device:MIDIDeviceRef = MIDIGetDevice(i)
            var offline:Int32 = 0
            MIDIObjectGetIntegerProperty(device, kMIDIPropertyOffline, &offline)
            if offline != 1 {
                let entityCount:Int = MIDIDeviceGetNumberOfEntities(device);
                for j in 0...entityCount {
                    let entity:MIDIEntityRef = MIDIDeviceGetEntity(device, j);
                    let destCount:Int = MIDIEntityGetNumberOfDestinations(entity);
                    if destCount > 0 {
                        var eOffline:Int32 = 0
                        MIDIObjectGetIntegerProperty(entity, kMIDIPropertyOffline, &eOffline)
                        if eOffline != 1 {
                            var unmanagedProperties: Unmanaged<CFPropertyList>?
                            /* JP: See NOTE1 at the beginning of file */
                            MIDIObjectGetProperties(entity, &unmanagedProperties, true)
                            if let midiProperties: CFPropertyList = unmanagedProperties?.takeUnretainedValue() {
                                let entityName = midiProperties["name"] as! String
                                let entityID = midiProperties["uniqueID"] as! Int
                                if !activeMIDIDevices.contains(entityID) {
                                    activeMIDIDeviceNames.append(entityName)
                                    activeMIDIDevices.append(entityID)
                                }
                            }
                        }
                    }
                }
            }
        }
        for i in 0...MIDIGetNumberOfDestinations()-1 {
            let device:MIDIDeviceRef = MIDIGetDestination(i)
            var offline:Int32 = 0
            MIDIObjectGetIntegerProperty(device, kMIDIPropertyOffline, &offline)
            if offline != 1 {
                var unmanagedProperties: Unmanaged<CFPropertyList>?
                /* JP: See NOTE1 at the beginning of file */
                MIDIObjectGetProperties(device, &unmanagedProperties, true)
                if let midiProperties: CFPropertyList = unmanagedProperties?.takeUnretainedValue() {
                    if midiProperties["name"]! != nil {
                        let entityName = midiProperties["name"] as! String
                        let entityID = midiProperties["uniqueID"] as! Int
                        if !activeMIDIDevices.contains(entityID) {
                            activeMIDIDeviceNames.append(entityName)
                            activeMIDIDevices.append(Int(entityID))
                        }
                    }
                }
            }
        }
    }

    public func send(MIDIChannel: UInt8, _ MIDIControl: UInt8, _ MIDIControlValue: UInt8) ->OSStatus {
        var packet:MIDIPacket = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
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