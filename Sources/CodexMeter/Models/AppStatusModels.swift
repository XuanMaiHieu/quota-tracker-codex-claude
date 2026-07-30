import Foundation

enum ConnectionStatus: Equatable {
    case connecting
    case connected
    case refreshing
    case error(String)
}
