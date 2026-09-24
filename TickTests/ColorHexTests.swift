import SwiftUI
import Testing
@testable import Tick

struct ColorHexTests {
    @Test func parsesWithAndWithoutHash() throws {
        let withHash = try #require(HexColor.components(from: "#FF8000"))
        let withoutHash = try #require(HexColor.components(from: "ff8000"))
        #expect(withHash.red == 1)
        #expect(withHash.green == 128.0 / 255)
        #expect(withHash.blue == 0)
        #expect(withHash == withoutHash)
    }

    @Test(arguments: ["", "#FFF", "#GG0000", "#12345678", "+12345", "red"])
    func rejectsInvalidHex(_ input: String) {
        #expect(HexColor.components(from: input) == nil)
    }

    @Test(arguments: ["#1A2B3C", "#000000", "#FFFFFF", "#8E8E93"])
    func roundTripsThroughColor(_ hex: String) {
        #expect(Color(hex: hex).hexString == hex)
    }

    @Test func invalidHexFallsBackToGrey() {
        #expect(Color(hex: "nonsense").hexString == HexColor.fallback)
    }

    @Test func formattingClampsOutOfRangeComponents() {
        #expect(HexColor.string(red: 1.2, green: -0.1, blue: 0.5) == "#FF0080")
    }
}
