import Foundation
import Testing

@testable import JSONLines

@Suite("AsyncJSONLinesSequence Tests", .timeLimit(.minutes(1)))
struct AsyncJSONLinesSequenceTests {
    // Test model object
    struct Todo: Codable, Equatable {
        let id: Int
        let title: String
        let completed: Bool
    }

    @Test("Basic JSON Line parsing from byte sequence")
    func testBasicJSONLineParsing() async throws {
        // Create a simple JSON Lines data string
        let jsonlData = """
            {"id": 1, "title": "Buy groceries", "completed": false}

            """

        // Convert to async sequence of bytes
        let byteSequence = AsyncBytes(jsonlData.utf8)

        // Use the jsonLines extension to get AsyncJSONLinesSequence
        let jsonlSequence = byteSequence.jsonLines(decoding: Todo.self)

        // Collect all items to verify
        var todos = [Todo]()
        for try await todo in jsonlSequence {
            todos.append(todo)
        }

        #expect(todos.count == 1)
        #expect(todos[0].id == 1)
        #expect(todos[0].title == "Buy groceries")
        #expect(todos[0].completed == false)
    }

    @Test("Multiple JSON Lines parsing")
    func testMultipleJSONLinesParsing() async throws {
        // Create a string with multiple JSON Lines
        let jsonlData = """
            {"id": 1, "title": "Buy groceries", "completed": false}
            {"id": 2, "title": "Clean house", "completed": true}

            """

        // Convert to async sequence of bytes
        let byteSequence = AsyncBytes(jsonlData.utf8)

        // Use the jsonLines extension
        let jsonlSequence = byteSequence.jsonLines(decoding: Todo.self)

        // Collect all todos
        var todos: [Todo] = []
        for try await todo in jsonlSequence {
            todos.append(todo)
        }

        #expect(todos.count == 2)
        #expect(todos[0].id == 1)
        #expect(todos[0].completed == false)
        #expect(todos[1].id == 2)
        #expect(todos[1].completed == true)
    }

    @Test("Empty sequence")
    func testEmptySequence() async throws {
        let emptySequence = AsyncBytes("".utf8).jsonLines(decoding: Todo.self)
        var iterator = emptySequence.makeAsyncIterator()
        let todo = try await iterator.next()
        #expect(todo == nil)
    }

    @Suite("Line Break Handling")
    struct LineBreakTests {
        @Test("CRLF line breaks")
        func testCRLFLineBreaks() async throws {
            let jsonlData = """
                {"id": 1, "title": "Task 1", "completed": false}\r\n
                """

            var iterator = AsyncBytes(jsonlData.utf8).jsonLines(decoding: Todo.self)
                .makeAsyncIterator()
            let todo = try await iterator.next()

            #expect(todo != nil)
            #expect(todo?.id == 1)
            #expect(todo?.title == "Task 1")
        }
    }

    @Suite("Empty Lines")
    struct EmptyLineTests {
        @Test("Empty lines between valid JSON")
        func testEmptyLines() async throws {
            let jsonlData = """
                {"id": 1, "title": "Task 1", "completed": false}

                {"id": 2, "title": "Task 2", "completed": true}

                """

            let jsonlSequence = AsyncBytes(jsonlData.utf8).jsonLines(decoding: Todo.self)

            var todos: [Todo] = []
            for try await todo in jsonlSequence {
                todos.append(todo)
            }

            #expect(todos.count == 2)
            #expect(todos[0].id == 1)
            #expect(todos[1].id == 2)
        }
    }

    @Suite("Chunked Data")
    struct ChunkedDataTests {
        @Test("Chunked delivery simulation")
        func testChunkedDelivery() async throws {
            // Simulate chunked JSON Lines data delivery
            let jsonlData = """
                {"id": 1, "title": "Buy groceries", "completed": false}
                {"id": 2, "title": "Clean house", "completed": true}
                """

            // Break the data into smaller chunks
            let allBytes = Array(jsonlData.utf8)
            let chunkSize = 10
            var chunks: [[UInt8]] = []

            for i in stride(from: 0, to: allBytes.count, by: chunkSize) {
                let end = min(i + chunkSize, allBytes.count)
                chunks.append(Array(allBytes[i..<end]))
            }

            let chunkedSequence = ChunkedAsyncBytes(chunks)

            // Collect all todos
            var todos: [Todo] = []
            for try await todo in chunkedSequence.jsonLines(decoding: Todo.self) {
                todos.append(todo)
            }

            #expect(todos.count == 2)
            #expect(todos[0].id == 1)
            #expect(todos[0].title == "Buy groceries")
            #expect(todos[1].id == 2)
            #expect(todos[1].title == "Clean house")
        }

        @Test("JSON spanning multiple chunks")
        func testJSONSpanningChunks() async throws {
            // Create a single large JSON object that will span multiple chunks
            let jsonlData = """
                {"id": 1, "title": "This is a very long title that will span multiple chunks when broken up into smaller pieces", "completed": false}
                {"id": 2, "title": "Another long title that should also span multiple chunks when broken into pieces", "completed": true}
                """

            // Break into fixed chunks for testing
            let allBytes = Array(jsonlData.utf8)
            let chunkSize = 20  // Small chunk size to ensure spanning
            var chunks: [[UInt8]] = []

            for i in stride(from: 0, to: allBytes.count, by: chunkSize) {
                let end = min(i + chunkSize, allBytes.count)
                chunks.append(Array(allBytes[i..<end]))
            }

            let chunkedSequence = ChunkedAsyncBytes(chunks)

            // Collect all todos
            var todos: [Todo] = []
            for try await todo in chunkedSequence.jsonLines(decoding: Todo.self) {
                todos.append(todo)
            }

            #expect(todos.count == 2)
            #expect(todos[0].id == 1)
            #expect(todos[0].completed == false)
            #expect(todos[1].id == 2)
            #expect(todos[1].completed == true)
        }
    }

    @Suite("Custom Decoder")
    struct CustomDecoderTests {
        @Test("Custom date decoding strategy")
        func testCustomDateDecoding() async throws {
            // Define a model with a date
            struct TodoWithDate: Codable, Equatable {
                let id: Int
                let title: String
                let dueDate: Date
            }

            // Create a custom decoder with a specific date decoding strategy
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let jsonlData = """
                {"id": 1, "title": "Task with date", "dueDate": "2023-05-15T10:00:00Z"}

                """

            // Use the custom decoder
            let sequence = AsyncBytes(jsonlData.utf8)
                .jsonLines(decoding: TodoWithDate.self, with: decoder)

            var iterator = sequence.makeAsyncIterator()
            let todo = try await iterator.next()

            #expect(todo != nil)
            #expect(todo?.id == 1)

            // Create an ISO8601 formatter to verify the date
            let formatter = ISO8601DateFormatter()
            let expectedDate = formatter.date(from: "2023-05-15T10:00:00Z")

            #expect(todo?.dueDate == expectedDate)
        }

        @Test("Explicit parameter naming")
        func testExplicitParameterNaming() async throws {
            let jsonlData = """
                {"id": 1, "title": "Task with explicit parameters", "completed": false}

                """

            // Test the explicit parameter naming syntax
            let sequence = AsyncBytes(jsonlData.utf8)
                .jsonLines(decoding: Todo.self, with: JSONDecoder())

            var iterator = sequence.makeAsyncIterator()
            let todo = try await iterator.next()

            #expect(todo != nil)
            #expect(todo?.id == 1)
            #expect(todo?.title == "Task with explicit parameters")
        }
    }

    @Suite("Error Handling")
    struct ErrorHandlingTests {
        @Test("Invalid JSON throws error")
        func testInvalidJSON() async throws {
            let invalidJSONData = """
                {"id": 1, "title": "Valid JSON", "completed": false}
                {"invalid": json without quotes}

                """

            let jsonlSequence = AsyncBytes(invalidJSONData.utf8).jsonLines(decoding: Todo.self)

            // Should get the first valid object
            var iterator = jsonlSequence.makeAsyncIterator()
            let firstTodo = try await iterator.next()
            #expect(firstTodo != nil)
            #expect(firstTodo?.id == 1)

            // The second line should throw an error
            do {
                _ = try await iterator.next()
                Issue.record("Expected decoding error but no error was thrown")
            } catch {
                #expect(error is DecodingError)
            }
        }
    }

    @Suite("JSONLines.org Examples")  // https://jsonlines.org/examples/
    struct JSONLinesOrgExamplesTests {
        @Test("Array-based CSV-like Format")
        func testArrayBasedFormat() async throws {
            // Define a model that matches the array structure
            struct CSVRow: Codable, Equatable {
                let name: String
                let session: String
                let score: Int
                let completed: Bool

                init(from decoder: Decoder) throws {
                    var container = try decoder.unkeyedContainer()
                    name = try container.decode(String.self)
                    session = try container.decode(String.self)
                    score = try container.decode(Int.self)
                    completed = try container.decode(Bool.self)
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.unkeyedContainer()
                    try container.encode(name)
                    try container.encode(session)
                    try container.encode(score)
                    try container.encode(completed)
                }
            }

            let jsonlData = """
                ["Gilbert", "2013", 24, true]
                ["Alexa", "2013", 29, true]
                ["May", "2012B", 14, false]
                ["Deloise", "2012A", 19, true]
                """

            let sequence = AsyncBytes(jsonlData.utf8).jsonLines(decoding: CSVRow.self)
            var rows: [CSVRow] = []

            for try await row in sequence {
                rows.append(row)
            }

            #expect(rows.count == 4)
            #expect(rows[0].name == "Gilbert")
            #expect(rows[0].session == "2013")
            #expect(rows[0].score == 24)
            #expect(rows[0].completed == true)
            #expect(rows[2].name == "May")
            #expect(rows[2].score == 14)
            #expect(rows[2].completed == false)
        }

        // Test model for tabular data
        struct Student: Codable, Equatable {
            let name: String
            let session: String
            let score: Int
            let completed: Bool
        }

        // Test model for nested data
        struct Player: Codable, Equatable {
            let name: String
            let wins: [[String]]
        }

        @Test("Tabular Data Example")
        func testTabularData() async throws {
            let jsonlData = """
                {"name": "Gilbert", "session": "2013", "score": 24, "completed": true}
                {"name": "Alexa", "session": "2013", "score": 29, "completed": true}
                {"name": "May", "session": "2012B", "score": 14, "completed": false}
                {"name": "Deloise", "session": "2012A", "score": 19, "completed": true}
                """

            let sequence = AsyncBytes(jsonlData.utf8).jsonLines(decoding: Student.self)
            var students: [Student] = []

            for try await student in sequence {
                students.append(student)
            }

            #expect(students.count == 4)
            #expect(students[0].name == "Gilbert")
            #expect(students[0].score == 24)
            #expect(students[0].completed == true)
            #expect(students[2].name == "May")
            #expect(students[2].score == 14)
            #expect(students[2].completed == false)
        }

        @Test("Nested Data Example")
        func testNestedData() async throws {
            let jsonlData = """
                {"name": "Gilbert", "wins": [["straight", "7♣"], ["one pair", "10♥"]]}
                {"name": "Alexa", "wins": [["two pair", "4♠"], ["two pair", "9♠"]]}
                {"name": "May", "wins": []}
                {"name": "Deloise", "wins": [["three of a kind", "5♣"]]}
                """

            let sequence = AsyncBytes(jsonlData.utf8).jsonLines(decoding: Player.self)
            var players: [Player] = []

            for try await player in sequence {
                players.append(player)
            }

            #expect(players.count == 4)
            #expect(players[0].name == "Gilbert")
            #expect(players[0].wins.count == 2)
            #expect(players[0].wins[0] == ["straight", "7♣"])
            #expect(players[2].name == "May")
            #expect(players[2].wins.isEmpty)
            #expect(players[3].wins[0] == ["three of a kind", "5♣"])
        }
    }
}
