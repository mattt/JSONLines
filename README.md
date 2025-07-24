# JSONLines

A lightweight library for working with [JSON Lines][jsonl] (JSONL) data in Swift.

## Features

- [x] Efficient parsing of [JSON Lines format](https://jsonlines.org/)
- [x] Streaming support via `AsyncSequence`
- [x] Line-by-line decoding to your model types
- [x] Support for custom `JSONDecoder` configuration
- [x] Handles chunked data and partial lines

## Requirements

- Swift 6.0+ / Xcode 16+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/loopwork/JSONLines.git", from: "1.0.0")
]
```

## Usage

### Processing JSON Lines from an AsyncSequence

Use the `jsonLines` extension method on any `AsyncSequence` of bytes to decode JSON objects line by line:

```swift
import JSONLines
import Foundation

// Create a model matching your JSON structure
struct Todo: Codable {
    let id: Int
    let title: String
    let completed: Bool
}

Task {
    // Get a byte stream from a URL or file
    let url = URL(string: "https://example.com/todos.jsonl")!
    let (stream, _) = try await URLSession.shared.bytes(for: URLRequest(url: url))

    // Process each JSON line as it arrives
    for try await todo in stream.jsonLines(decoding: Todo.self) {
        print("Todo #\(todo.id): \(todo.title)\(todo.completed ? " ✓ Completed" : "")")
    }
}
```

### Using a Custom Decoder

You can provide your own `JSONDecoder` for custom decoding strategies:

```swift
import JSONLines
import Foundation

struct LogEntry: Codable {
    let timestamp: Date
    let level: String
    let message: String
}

Task {
    // Set up a custom decoder with date decoding strategy
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // Get data from a file
    let fileURL = URL(fileURLWithPath: "/path/to/logs.jsonl")
    let data = try Data(contentsOf: fileURL)

    // Process the JSON Lines with the custom decoder
    for try await entry in data.jsonLines(decoding: LogEntry.self, with: decoder) {
        print("[\(entry.timestamp)] [\(entry.level)] \(entry.message)")
    }
}
```

## Examples

### Processing Large JSONL Files

JSON Lines is perfect for processing large datasets efficiently without loading everything into memory:

```swift
import JSONLines
import Foundation

struct DataPoint: Codable {
    let id: String
    let values: [Double]
}

func processDataPoint(_ point: DataPoint) { /* ... */ }

Task {
    // Open a file handle to a large JSONL file
    let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: "/path/to/large-dataset.jsonl"))
    defer { try? fileHandle.close() }

    // Process the data one line at a time
    var count = 0
    for try await dataPoint in fileHandle.bytes.jsonLines(decoding: DataPoint.self) {
        // Process each data point individually
        processDataPoint(dataPoint)

        count += 1
        if count % 1000 == 0 {
            print("Processed \(count) data points")
        }
    }
}
```

## License

This project is available under the MIT license.
See the LICENSE file for more info.

[jsonl]: https://jsonlines.org/