import Testing

@testable import ScreenInkCore

@Test func modifierTapNeedsSoloQuickPress() {
    let leftCommand = 55
    var tap = ModifierTap()
    #expect(tap.flagsChanged(keyCode: leftCommand, flags: 0x10_0008, time: 0) == nil)
    #expect(tap.flagsChanged(keyCode: leftCommand, flags: 0, time: 0.2) == leftCommand)

    _ = tap.flagsChanged(keyCode: leftCommand, flags: 0x10_0008, time: 1)
    tap.interrupt()  // e.g. ⌘C
    #expect(tap.flagsChanged(keyCode: leftCommand, flags: 0, time: 1.1) == nil)

    _ = tap.flagsChanged(keyCode: leftCommand, flags: 0x10_0008, time: 2)
    #expect(tap.flagsChanged(keyCode: leftCommand, flags: 0, time: 3) == nil)  // held too long

    _ = tap.flagsChanged(keyCode: 56, flags: 0x2_0002, time: 4)  // ⇧ held, then ⌘
    #expect(tap.flagsChanged(keyCode: leftCommand, flags: 0x12_000A, time: 4.1) == nil)
    #expect(tap.flagsChanged(keyCode: leftCommand, flags: 0x2_0002, time: 4.2) == nil)

    #expect(Shortcut.modifierOnly(keyCode: leftCommand)?.label == "Left ⌘")
    #expect(Shortcut.modifierOnly(keyCode: leftCommand)?.isValid == true)
}
