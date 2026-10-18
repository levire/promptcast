import AppKit
import Carbon.HIToolbox
import PromptCastCore

extension Shortcut {
    /// The key and modifiers of a key-down event, with the key's display name.
    init(event: NSEvent) {
        let modifiers = [
            (NSEvent.ModifierFlags.control, Shortcut.control), (.option, Shortcut.option), (.shift, Shortcut.shift),
            (.command, Shortcut.command),
        ]
        .filter { event.modifierFlags.contains($0.0) }.reduce(0) { $0 | $1.1 }
        let names = [
            kVK_Escape: "Esc", kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_F1: "F1",
            kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        let key = names[Int(event.keyCode)] ?? event.charactersIgnoringModifiers?.uppercased() ?? "?"
        self.init(keyCode: Int(event.keyCode), modifiers: modifiers, key: key)
    }
}
