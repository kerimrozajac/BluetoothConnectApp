import SwiftUI

struct MainView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var selectedDevice: BluetoothDevice?
    @State private var textToSend: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Bluetooth Devices")
                    .font(.headline)

                List(bluetoothManager.discoveredDevices) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        if bluetoothManager.connectedDevice == device {
                            Text("Connected")
                                .foregroundColor(.green)
                        } else if selectedDevice == device {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if bluetoothManager.connectedDevice == device {
                            // If the device is already connected, disconnect it
                            bluetoothManager.disconnectFromDevice()
                        } else {
                            // If the device is not connected, connect to it
                            selectedDevice = device
                            bluetoothManager.connectToDevice(device)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())

                // Add the second VStack with the text box and send button
                VStack {
                    TextField("Enter message", text: $textToSend)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    Button(action: {
                        sendDataToDevice()
                    }) {
                        Text("Send")
                            .foregroundColor(.white)
                            .padding()
                            .background(bluetoothManager.connectedDevice != nil ? Color.blue : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(bluetoothManager.connectedDevice == nil)  // Disable button when no device is connected
                }
                .padding()
            }
            .padding()
            .onAppear {
                bluetoothManager.startScanning()
            }
            .onDisappear {
                bluetoothManager.stopScanning()
            }
            .navigationTitle("Devices")
        }
        .onChange(of: bluetoothManager.connectedDevice) { oldDevice, newDevice in
            selectedDevice = nil
        }
    }
    
    // Function to send data to the connected device
    func sendDataToDevice() {
        guard let connectedDevice = bluetoothManager.connectedDevice else {
            return
        }

        // Verify that the text to send is in the expected format
        guard textToSend == "N" || textToSend == "F" else {
            print("Invalid data format: \(textToSend). Only 'N' or 'F' are allowed.")
            return
        }

        // Send data to the connected device
        bluetoothManager.sendData(textToSend)

        print("Sending message to \(connectedDevice.name): \(textToSend)")
    }

}

// Replace the preview if necessary for newer Swift versions
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
