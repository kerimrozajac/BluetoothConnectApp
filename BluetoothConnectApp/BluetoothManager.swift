import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var connectedDevice: BluetoothDevice?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var peripheralMap: [UUID: CBPeripheral] = [:] // Map to keep track of peripherals

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on.")
            return
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("Started scanning for devices.")
    }

    func stopScanning() {
        centralManager.stopScan()
        print("Stopped scanning for devices.")
    }

    func connectToDevice(_ device: BluetoothDevice, timeout: TimeInterval = 10.0) {
        guard let peripheral = peripheralMap[device.id] else { return }
        stopScanning()
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if self.connectedDevice?.id != device.id {
                print("Connection timeout for \(device.name).")
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    func disconnectFromDevice() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - Sending Data to Device

    func sendData(_ data: String) {
        guard let peripheral = connectedPeripheral, let characteristic = self.characteristic else {
            print("No connected peripheral or characteristic found.")
            return
        }

        // Convert string to data
        let dataToSend = Data(data.utf8)

        // Verify data size using the CBPeripheral's method
        let maxWriteLength = peripheral.maximumWriteValueLength(for: .withResponse)
        if dataToSend.count > maxWriteLength {
            print("Data size exceeds maximum allowable size of \(maxWriteLength) bytes.")
            return
        }

        // Write data to the characteristic
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)

        print("Data sent to \(peripheral.name ?? "Unknown Device"): \(data)")
    }




    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            stopScanning()
        case .resetting:
            print("Bluetooth resetting. Waiting for stabilization.")
        case .unauthorized:
            print("Bluetooth unauthorized. Check app permissions.")
        case .unsupported:
            print("Bluetooth unsupported on this device.")
        case .unknown:
            print("Bluetooth state is unknown.")
        @unknown default:
            print("Unhandled Bluetooth state.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !peripheralMap.keys.contains(peripheral.identifier) {
            peripheralMap[peripheral.identifier] = peripheral
            let device = BluetoothDevice(id: peripheral.identifier, name: peripheral.name ?? "Unknown Device")
            DispatchQueue.main.async {
                self.discoveredDevices.append(device)
            }
        }
        peripheral.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let connectedDevice = discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
            DispatchQueue.main.async {
                self.connectedDevice = connectedDevice
            }
        }
        print("Connected to device: \(peripheral.name ?? "Unknown Device")")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("Disconnected with error: \(error.localizedDescription)")
        } else {
            print("Disconnected from \(peripheral.name ?? "Unknown Device").")
        }
        DispatchQueue.main.async {
            self.connectedDevice = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error)")
            return
        }
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value to characteristic \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            print("Successfully wrote value to characteristic \(characteristic.uuid).")
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic.uuid)")
            self.characteristic = characteristic
        }
    }
}
