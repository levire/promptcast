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

@Test func doublePressStartsOverAfterASlowSecondPress() {
    var trigger = CancelTrigger(twice: true)
    _ = trigger.press(at: 0)
    #expect(trigger.press(at: 1.1) == .pressAgain, "a press more than one second later starts over")
    #expect(trigger.press(at: 1.5) == .cancel, "the slow press then counts as a new first press")
}

@Test func cancelKeysMatchTheSystemKeyCodes() {
    let system = [
        kVK_Escape, kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
    ]
    #expect(CancelKey.allCases.map(\.rawValue) == system, "each case is the Carbon key code of the key it names")
}
