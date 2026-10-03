import CoreGraphics
import Foundation
import Testing
@testable import Tick

struct WindowPlacementTests {
    let mainDisplay = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let rightDisplay = CGRect(x: 1440, y: 0, width: 1920, height: 1055)

    @Test func keepsAWindowAlreadyOnTheDisplay() {
        let frame = CGRect(x: 100, y: 100, width: 820, height: 560)
        #expect(WindowPlacement.frame(frame, on: mainDisplay) == frame)
    }

    @Test func keepsAWindowWhoseCentreIsOnTheDisplay() {
        let frame = CGRect(x: 1000, y: 100, width: 820, height: 560)  // Overhangs to the right.
        #expect(WindowPlacement.frame(frame, on: mainDisplay) == frame)
    }

    @Test func centresAWindowFromAnotherDisplay() {
        let frame = CGRect(x: 100, y: 100, width: 820, height: 560)
        #expect(WindowPlacement.frame(frame, on: rightDisplay) == CGRect(x: 1990, y: 247.5, width: 820, height: 560))
    }

    @Test func shrinksAWindowLargerThanTheDisplay() {
        let frame = CGRect(x: 1500, y: 0, width: 1900, height: 1000)
        #expect(WindowPlacement.frame(frame, on: mainDisplay) == mainDisplay)
    }
}
