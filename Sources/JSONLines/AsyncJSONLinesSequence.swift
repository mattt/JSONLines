import Foundation

/// An `AsyncSequence` that transforms a sequence of bytes
/// into a sequence of values decoded from JSON Lines format.
public struct AsyncJSONLinesSequence<Base: AsyncSequence, T: Decodable>: AsyncSequence
where Base.Element == UInt8 {
    /// The type of elements in the sequence.
    public typealias Element = T

    /// The type of the iterator for the sequence.
    public typealias AsyncIterator = Iterator

    let base: Base
    let decoder: JSONDecoder

    /// Creates a new `AsyncJSONLinesSequence` from a base sequence of bytes.
    public init(base: Base, decoder: JSONDecoder = JSONDecoder()) {
        self.base = base
        self.decoder = decoder
    }

    /// Creates an iterator for the sequence.
    public func makeAsyncIterator() -> Iterator {
        return Iterator(base: base.makeAsyncIterator(), decoder: decoder)
    }

    /// An iterator for the sequence.
    public struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        var buffer: [UInt8] = []
        var decoder: JSONDecoder

        init(base: Base.AsyncIterator, decoder: JSONDecoder) {
            self.baseIterator = base
            self.decoder = decoder
        }

        public mutating func next() async throws -> T? {
            // ASCII value for newline
            let newline: UInt8 = 0x0A

            // Process bytes until we get a complete line or run out of input
            repeat {
                // Check if buffer already contains a complete line
                if let newlineIndex = buffer.firstIndex(of: newline) {
                    let lineData = Data(buffer[..<newlineIndex])
                    buffer.removeSubrange(..<(newlineIndex + 1))

                    // Skip empty lines
                    if lineData.isEmpty {
                        continue
                    }

                    // Decode JSON data
                    return try decoder.decode(T.self, from: lineData)
                }

                // Get next byte from the base iterator
                guard let byte = try await baseIterator.next() else {
                    // Base sequence ended; check if there's any data left in the buffer
                    if buffer.isEmpty {
                        return nil
                    } else {
                        let lineData = Data(buffer)
                        buffer.removeAll()
                        return try decoder.decode(T.self, from: lineData)
                    }
                }

                buffer.append(byte)
            } while true
        }
    }
}
