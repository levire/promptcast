import Testing

@testable import ScreenInkCore

@Test func shortcutLabelAndValidity() {
    #expect(Shortcut.standard.label == "⌃⌥R")
    let all = Shortcut(keyCode: 49, modifiers: Shortcut.command | Shortcut.shift | Shortcut.control, key: "Space")
    #expect(all.label == "⌃⇧⌘Space")
    #expect(!Shortcut(keyCode: 15, modifiers: Shortcut.shift, key: "R").isValid)
}
