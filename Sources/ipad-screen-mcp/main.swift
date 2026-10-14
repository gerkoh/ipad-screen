import Foundation
import iPadScreenCore

// stdout carries only protocol messages; anything else would corrupt the stream.
let capturer = HelperCapture(appURL: HelperCapture.locateApp())
let server = MCPServer { capturer.capture() }

while let line = readLine(strippingNewline: true) {
    guard !line.allSatisfy(\.isWhitespace) else { continue }
    if let reply = server.handle(line: line) {
        FileHandle.standardOutput.write(Data((reply + "\n").utf8))
    }
}
