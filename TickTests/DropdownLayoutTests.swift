import AppKit
import Testing
@testable import Tick

struct DropdownLayoutTests {
    // A 1512x982 main display with a 33 pt menu bar.
    let main = NSRect(x: 0, y: 0, width: 1512, height: 949)
    let width: CGFloat = 340

    @Test func hangsBelowTheItemWithLeftEdgesAligned() {
        let item = NSRect(x: 900, y: 949, width: 120, height: 33)
        let topLeft = DropdownLayout.topLeft(below: item, width: width, in: main)
        #expect(topLeft == NSPoint(x: 900, y: 945))
    }

    @Test func isPushedLeftNearTheRightEdge() {
        let item = NSRect(x: 1400, y: 949, width: 80, height: 33)
        let topLeft = DropdownLayout.topLeft(below: item, width: width, in: main)
        let expectedX: CGFloat = 1512 - 8 - 340
        #expect(topLeft.x == expectedX)
    }

    @Test func staysOnScreenNearTheLeftEdge() {
        let item = NSRect(x: 2, y: 949, width: 30, height: 33)
        #expect(DropdownLayout.topLeft(below: item, width: width, in: main).x == 8)
    }

    @Test func worksOnASecondaryScreenWithNegativeCoordinates() {
        // A display to the left of and higher than the main one.
        let secondary = NSRect(x: -1920, y: 200, width: 1920, height: 1055)
        let item = NSRect(x: -700, y: 1255, width: 150, height: 25)
        let topLeft = DropdownLayout.topLeft(below: item, width: width, in: secondary)
        #expect(topLeft == NSPoint(x: -700, y: 1251))
    }

    @Test func frameHangsDownFromTheTopLeftCorner() {
        let frame = DropdownLayout.frame(topLeft: NSPoint(x: 900, y: 945), size: CGSize(width: 340, height: 300))
        #expect(frame == NSRect(x: 900, y: 645, width: 340, height: 300))
        #expect(frame.maxY == 945)
    }
}
