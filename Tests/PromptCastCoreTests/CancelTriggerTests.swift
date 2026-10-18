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
