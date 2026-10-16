import Carbon.HIToolbox
import Testing

@testable import PromptCastCore

@Test func modifierConstantsMatchCarbonFlags() {
    #expect(Shortcut.command == cmdKey, "Hotkey passes this to RegisterEventHotKey")
    #expect(Shortcut.shift == shiftKey, "Hotkey passes this to RegisterEventHotKey")
    #expect(Shortcut.option == optionKey, "Hotkey passes this to RegisterEventHotKey")
    #expect(Shortcut.control == controlKey, "Hotkey passes this to RegisterEventHotKey")
}

@Test func standardShortcutIsControlOptionR() {
    #expect(Shortcut.standard.keyCode == kVK_ANSI_R, "standard key is R")
    #expect(Shortcut.standard.modifiers == controlKey | optionKey, "standard modifiers are ⌃⌥")
    #expect(Shortcut.standard.label == "⌃⌥R", "standard label is ⌃⌥R")
}

@Test func labelListsModifiersInMacOrder() {
    let all = Shortcut(keyCode: kVK_Space, modifiers: cmdKey | shiftKey | optionKey | controlKey, key: "Space")
    #expect(all.label == "⌃⌥⇧⌘Space", "all four modifiers read ⌃⌥⇧⌘")
}

@Test func labelOmitsModifiersThatAreNotSet() {
    let shortcut = Shortcut(keyCode: kVK_ANSI_K, modifiers: shiftKey | cmdKey, key: "K")
    #expect(shortcut.label == "⇧⌘K", "only ⇧ and ⌘ are listed")
}

@Test(arguments: [("control", controlKey), ("option", optionKey), ("command", cmdKey)])
func combinationWithOneOfControlOptionCommandIsValid(name: String, modifiers: Int) {
    let shortcut = Shortcut(keyCode: kVK_ANSI_R, modifiers: modifiers, key: "R")
    #expect(shortcut.isValid, "\(name) alone makes a key combination valid")
}

@Test func combinationWithOnlyShiftIsInvalid() {
    let shortcut = Shortcut(keyCode: kVK_ANSI_R, modifiers: shiftKey, key: "R")
    #expect(!shortcut.isValid, "⇧R would swallow typing")
}

@Test func combinationWithoutModifiersIsInvalid() {
    let shortcut = Shortcut(keyCode: kVK_ANSI_R, modifiers: 0, key: "R")
    #expect(!shortcut.isValid, "a bare letter would swallow typing")
}

@Test func modifierOnlyShortcutIsValidAndNamed() {
    let shortcut = Shortcut.modifierOnly(keyCode: kVK_Command)
    #expect(shortcut?.label == "Left ⌘", "key code 55 is Left ⌘")
    #expect(shortcut?.isValid == true, "a modifier key alone is valid")
    #expect(shortcut?.isModifierOnly == true, "no modifiers and a modifier key code")
}

@Test func modifierOnlyIsNilForNonModifierKey() {
    #expect(Shortcut.modifierOnly(keyCode: kVK_ANSI_A) == nil, "key code 0 is the letter A")
}

@Test func shortcutWithModifiersIsNotModifierOnly() {
    let shortcut = Shortcut(keyCode: kVK_Command, modifiers: controlKey, key: "Left ⌘")
    #expect(!shortcut.isModifierOnly, "set modifiers make it a combination")
}
