import Foundation

extension Equatable {
    @inlinable func contained(in elements: [Self]) -> Bool {
        elements.contains(self)
    }
}