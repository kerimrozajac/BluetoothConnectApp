import Foundation

struct BluetoothDevice: Identifiable, Hashable {
    let id: UUID
    let name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
