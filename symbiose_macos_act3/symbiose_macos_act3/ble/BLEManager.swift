import Foundation
import SwiftUI
import CoreBluetooth

class BLEManager: NSObject {
    static let instance = BLEManager()
    
    var isBLEEnabled = false
    var isScanning = false
    let authCBUUID = CBUUID(string: "5DCDC3CA-D630-4727-9650-EFB39FCCC6BA")
    let writeCBUUID = CBUUID(string: "D2C020B7-BE30-442E-9B0D-EB46B830C8F2")
    let readCBUUID = CBUUID(string: "A43BAE09-373C-434A-A821-C7892E42BB4D")
    let readCityCBUUID = CBUUID(string: "558759EE-0F86-49E7-A38A-DBE48CF8B237")
    var centralManager: CBCentralManager?
    var connectedPeripherals = [CBPeripheral]()
    var readyPeripherals = [CBPeripheral]()
    
    var scanCallback: ((CBPeripheral,String) -> ())?
    var connectCallback: ((CBPeripheral) -> ())?
    var disconnectCallback: ((CBPeripheral) -> ())?
    var didFinishDiscoveryCallback: ((CBPeripheral) -> ())?
    var globalDisconnectCallback: ((CBPeripheral) -> ())?
    var sendDataCallback: ((String?) -> ())?
    var messageReceivedCallback:((Data?)->())?
    var cityMessageReceivedCallback:((Data?)->())?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func clear() {
        connectedPeripherals = []
        readyPeripherals = []
    }
    
    func scan(callback: @escaping (CBPeripheral,String) -> ()) {
        isScanning = true
        scanCallback = callback
        centralManager?.scanForPeripherals(withServices: [], options: [CBCentralManagerScanOptionAllowDuplicatesKey:NSNumber(value: false)])
    }
    
    func stopScan() {
        isScanning = false
        centralManager?.stopScan()
    }
    
    func listenForMessages(callback:@escaping(Data?)->()) {
        messageReceivedCallback = callback
    }
    
    func listenForCityMessages(callback:@escaping(Data?)->()) {
        cityMessageReceivedCallback = callback
    }
    
    func connectPeripheral(_ periph: CBPeripheral, callback: @escaping (CBPeripheral) -> ()) {
        connectCallback = callback
        centralManager?.connect(periph, options: nil)
    }
    
    func disconnectPeripheral(_ periph: CBPeripheral, callback: @escaping (CBPeripheral) -> ()) {
        disconnectCallback = callback
        centralManager?.cancelPeripheralConnection(periph)
    }
    
    func didDisconnectPeripheral(callback: @escaping (CBPeripheral) -> ()) {
        disconnectCallback = callback
        globalDisconnectCallback = callback
    }
    
    func discoverPeripheral(_ periph: CBPeripheral, callback: @escaping (CBPeripheral) -> ()) {
        didFinishDiscoveryCallback = callback
        periph.delegate = self
        periph.discoverServices(nil)
        
    }
    
    func getCharForUUID(_ uuid: CBUUID, forperipheral peripheral: CBPeripheral) -> CBCharacteristic? {
        if let services = peripheral.services {
            for service in services {
                if let characteristics = service.characteristics {
                    for char in characteristics {
                        if char.uuid == uuid {
                            return char
                        }
                    }
                }
            }
        }
        return nil
    }
    
    func sendData(data: Data, callback: @escaping (String?) -> ()) {
        sendDataCallback = callback
        for periph in readyPeripherals {
            if let char = BLEManager.instance.getCharForUUID(writeCBUUID, forperipheral: periph) {
                periph.writeValue(data, for: char, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
   
    func sendStopCityData(data: Data, callback: @escaping (String?) -> ()) {
        sendDataCallback = callback
        for periph in readyPeripherals {
            if let char = BLEManager.instance.getCharForUUID(readCityCBUUID, forperipheral: periph) {
                periph.writeValue(data, for: char, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    func sendStopData(data: Data, callback: @escaping (String?) -> ()) {
        sendDataCallback = callback
        for periph in readyPeripherals {
            if let char = BLEManager.instance.getCharForUUID(readCBUUID, forperipheral: periph) {
                periph.writeValue(data, for: char, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }

    func readData() {
        for periph in readyPeripherals {
            if let char = BLEManager.instance.getCharForUUID(readCBUUID, forperipheral: periph) {
                periph.readValue(for: char)
            }
        }
    }

}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let services = peripheral.services {
            let count = services.filter { $0.characteristics == nil }.count
            if count == 0 {
                for s in services {
                    for c in s.characteristics! {
                            peripheral.setNotifyValue(true, for: c)
                    }
                }
                readyPeripherals.append(peripheral)
                didFinishDiscoveryCallback?(peripheral)
            }
        }
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isBLEEnabled = true
        } else {
            isBLEEnabled = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        scanCallback?(peripheral,localName)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if !connectedPeripherals.contains(peripheral) {
            connectedPeripherals.append(peripheral)
            connectCallback?(peripheral)
        }
    }
        
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripherals.removeAll { $0 == peripheral }
        readyPeripherals.removeAll { $0 == peripheral }
        disconnectCallback?(peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic == getCharForUUID(readCityCBUUID, forperipheral: peripheral){
            cityMessageReceivedCallback?(characteristic.value)
        }
        if characteristic == getCharForUUID(writeCBUUID, forperipheral: peripheral){
            messageReceivedCallback?(characteristic.value)
        }
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        sendDataCallback?(peripheral.name)
    }
}
