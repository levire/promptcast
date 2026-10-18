import Carbon.HIToolbox
import Testing

@testable import PromptCastCore

// Device-dependent flag bits from IOKit's IOLLEvent.h (NX_DEVICE*KEYMASK).
private let deviceLeftControl: UInt64 = 0x1
private let deviceLeftShift: UInt64 = 0x2
private let deviceRightShift: UInt64 = 0x4
private let deviceLeftCommand: UInt64 = 0x8
private let deviceRightCommand: UInt64 = 0x10
private let deviceLeftOption: UInt64 = 0x20
private let deviceRightOption: UInt64 = 0x40
private let deviceRightControl: UInt64 = 0x2000
private let functionFlag: UInt64 = 0x80_0000  // NSEvent.ModifierFlags.function

@Test func soloQuickPressFires() {
    var tap = ModifierTap()
    #expect(tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 0) == nil, "press does not fire")
    #expect(
        tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 0.2) == kVK_Command, "quick release fires the key code")
}

@Test func releaseExactlyAtHalfSecondFires() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 1)
    #expect(tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 1.5) == kVK_Command, "0.5 s hold still fires")
}

@Test func releaseAfterHalfSecondDoesNotFire() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 1)
    #expect(tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 1.51) == nil, "a hold past 0.5 s is not a tap")
}

@Test func interruptCancelsTap() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 0)
    tap.interrupt()
    #expect(tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 0.1) == nil, "a key press in between cancels")
}

@Test func otherModifierHeldBeforePressCancelsTap() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Shift, flags: deviceLeftShift, time: 0)
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftShift | deviceLeftCommand, time: 0.1)
    #expect(
        tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftShift, time: 0.2) == nil,
        "⌘ pressed while ⇧ is held is not solo")
}

@Test func otherModifierPressedWhileHeldCancelsTap() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 0)
    _ = tap.flagsChanged(keyCode: kVK_Shift, flags: deviceLeftCommand | deviceLeftShift, time: 0.1)
    #expect(
        tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftShift, time: 0.2) == nil,
        "⇧ pressed during the ⌘ hold cancels")
}

@Test func releasingDifferentKeyDoesNotFire() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 0)
    #expect(tap.flagsChanged(keyCode: kVK_RightCommand, flags: 0, time: 0.1) == nil, "right ⌘ release is not left ⌘")
}

@Test func unrelatedModifierEventCancelsTap() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 0)
    _ = tap.flagsChanged(keyCode: kVK_CapsLock, flags: deviceLeftCommand, time: 0.1)
    #expect(tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 0.2) == nil, "caps lock in between cancels")
}

@Test func secondReleaseAfterFiredTapDoesNotFireAgain() {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: deviceLeftCommand, time: 0)
    _ = tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 0.1)
    #expect(tap.flagsChanged(keyCode: kVK_Command, flags: 0, time: 0.2) == nil, "one press fires once")
}

@Test(arguments: [
    (kVK_RightCommand, deviceRightCommand), (kVK_Command, deviceLeftCommand),
    (kVK_Shift, deviceLeftShift), (kVK_RightShift, deviceRightShift),
    (kVK_Option, deviceLeftOption), (kVK_RightOption, deviceRightOption),
    (kVK_Control, deviceLeftControl), (kVK_RightControl, deviceRightControl),
    (kVK_Function, functionFlag),
])
func eachModifierKeyFiresOnItsOwnDeviceBit(keyCode: Int, flag: UInt64) {
    var tap = ModifierTap()
    _ = tap.flagsChanged(keyCode: keyCode, flags: flag, time: 0)
    #expect(tap.flagsChanged(keyCode: keyCode, flags: 0, time: 0.1) == keyCode, "key code \(keyCode) taps via \(flag)")
}
