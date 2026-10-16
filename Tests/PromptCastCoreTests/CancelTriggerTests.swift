import Carbon.HIToolbox
import Testing

@testable import PromptCastCore

@Test func singlePressCancels() {
    var trigger = CancelTrigger(twice: false)
    #expect(trigger.press(at: 0) == .cancel, "single-press mode cancels on the first press")
}

@Test func doublePressAsksForASecondPress() {
    var trigger = CancelTrigger(twice: true)
    #expect(trigger.press(at: 0) == .pressAgain, "the first press only asks for a second one")
}

@Test func doublePressCancelsOnASecondPressOneSecondLater() {
    var trigger = CancelTrigger(twice: true)
    _ = trigger.press(at: 0)
    #expect(trigger.press(at: 1.0) == .cancel, "a second press one second later still counts")
}

@Test func slowSecondPressOnlyAsksAgain() {
    var trigger = CancelTrigger(twice: true)
    _ = trigger.press(at: 0)
    #expect(trigger.press(at: 1.1) == .pressAgain, "a press more than one second later does not cancel")
}

@Test func slowSecondPressCountsAsANewFirstPress() {
    var trigger = CancelTrigger(twice: true)
    _ = trigger.press(at: 0)
    _ = trigger.press(at: 1.1)
    #expect(trigger.press(at: 1.5) == .cancel, "a press soon after the slow one cancels")
}

private let systemKeyCodes: [CancelKey: Int] = [
    .escape: kVK_Escape, .f1: kVK_F1, .f2: kVK_F2, .f3: kVK_F3, .f4: kVK_F4, .f5: kVK_F5, .f6: kVK_F6,
    .f7: kVK_F7, .f8: kVK_F8, .f9: kVK_F9, .f10: kVK_F10, .f11: kVK_F11, .f12: kVK_F12,
]

@Test(arguments: CancelKey.allCases)
func cancelKeyIsTheSystemKeyCode(key: CancelKey) throws {
    let code = try #require(systemKeyCodes[key], "\(key) has no expected system key code")
    #expect(key.rawValue == code, "\(key) is the Carbon key code of the key it names")
}

@Test func everyCancelKeyHasAnExpectedKeyCode() {
    for key in CancelKey.allCases {
        #expect(systemKeyCodes[key] != nil, "\(key) is missing from the expected key codes")
    }
}

@Test func escapeLabelIsEsc() {
    #expect(CancelKey.escape.label == "Esc", "the escape key is labeled Esc")
}

@Test func functionKeyLabelsAreUppercase() {
    #expect(CancelKey.f1.label == "F1", "f1 is labeled F1")
    #expect(CancelKey.f12.label == "F12", "f12 is labeled F12")
}
