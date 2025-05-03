import Foundation

extension AsyncSequence where Element == UInt8 {
    /// Returns an asynchronous sequence of values decoded from JSON Lines format.
    /// Each line in the input is parsed as a separate JSON object and decoded to type `T`.
    ///
    /// - Parameter type: The type to decode each JSON line to.
    /// - Parameter decoder: The decoder to use for decoding JSON lines.
    /// - Returns: An asynchronous sequence of decoded values.
    public func jsonLines<T: Decodable>(
        decoding type: T.Type,
        with decoder: JSONDecoder = JSONDecoder()
    ) -> AsyncJSONLinesSequence<Self, T> {
        return AsyncJSONLinesSequence(base: self, decoder: decoder)
    }
}
