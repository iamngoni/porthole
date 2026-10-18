import Foundation

/// USB HID keyboard usages (page 0x07) and how they map to macOS virtual key codes.
public enum HIDKeyMap {
    public enum Usage {
        public static let returnKey: UInt16 = 0x28
        public static let escape: UInt16 = 0x29
        public static let deleteBackward: UInt16 = 0x2A
        public static let tab: UInt16 = 0x2B
        public static let space: UInt16 = 0x2C
        public static let q: UInt16 = 0x14
        public static let rightArrow: UInt16 = 0x4F
        public static let leftArrow: UInt16 = 0x50
        public static let downArrow: UInt16 = 0x51
        public static let upArrow: UInt16 = 0x52
        public static let leftControl: UInt16 = 0xE0
        public static let leftShift: UInt16 = 0xE1
        public static let leftOption: UInt16 = 0xE2
        public static let leftCommand: UInt16 = 0xE3
    }

    /// macOS virtual key code (`kVK_*`) for a HID usage, or nil for keys the Mac has no equivalent of.
    public static func virtualKey(forUsage usage: UInt16) -> UInt16? {
        virtualKeys[usage]
    }

    /// The modifier a modifier key's usage stands for (left and right alike).
    public static func modifier(forUsage usage: UInt16) -> Modifiers? {
        switch usage {
        case 0xE0, 0xE4: .control
        case 0xE1, 0xE5: .shift
        case 0xE2, 0xE6: .option
        case 0xE3, 0xE7: .command
        default: nil
        }
    }

    public static var allUsages: [UInt16] { Array(virtualKeys.keys).sorted() }

    /// F1–F12 and F13–F20.
    public static func isFunctionKey(_ usage: UInt16) -> Bool {
        (0x3A...0x45).contains(usage) || (0x68...0x6F).contains(usage)
    }

    /// The key that types `character` on a US layout, and whether it needs Shift.
    /// Used for shortcuts typed with the on-screen modifier keys, which need a key, not text.
    public static func usage(forCharacter character: Character) -> (usage: UInt16, shift: Bool)? {
        if let ascii = character.asciiValue {
            switch ascii {
            case UInt8(ascii: "a")...UInt8(ascii: "z"):
                return (0x04 + UInt16(ascii - UInt8(ascii: "a")), false)
            case UInt8(ascii: "A")...UInt8(ascii: "Z"):
                return (0x04 + UInt16(ascii - UInt8(ascii: "A")), true)
            case UInt8(ascii: "1")...UInt8(ascii: "9"):
                return (0x1E + UInt16(ascii - UInt8(ascii: "1")), false)
            case UInt8(ascii: "0"):
                return (0x27, false)
            default:
                break
            }
        }
        return punctuation[character]
    }

    private static let punctuation: [Character: (usage: UInt16, shift: Bool)] = [
        "\n": (0x28, false), "\r": (0x28, false), "\t": (0x2B, false), " ": (0x2C, false),
        "!": (0x1E, true), "@": (0x1F, true), "#": (0x20, true), "$": (0x21, true), "%": (0x22, true),
        "^": (0x23, true), "&": (0x24, true), "*": (0x25, true), "(": (0x26, true), ")": (0x27, true),
        "-": (0x2D, false), "_": (0x2D, true), "=": (0x2E, false), "+": (0x2E, true),
        "[": (0x2F, false), "{": (0x2F, true), "]": (0x30, false), "}": (0x30, true),
        "\\": (0x31, false), "|": (0x31, true), ";": (0x33, false), ":": (0x33, true),
        "'": (0x34, false), "\"": (0x34, true), "`": (0x35, false), "~": (0x35, true),
        ",": (0x36, false), "<": (0x36, true), ".": (0x37, false), ">": (0x37, true),
        "/": (0x38, false), "?": (0x38, true),
    ]

    private static let virtualKeys: [UInt16: UInt16] = [
        // Letters a–z
        0x04: 0x00, 0x05: 0x0B, 0x06: 0x08, 0x07: 0x02, 0x08: 0x0E, 0x09: 0x03, 0x0A: 0x05, 0x0B: 0x04,
        0x0C: 0x22, 0x0D: 0x26, 0x0E: 0x28, 0x0F: 0x25, 0x10: 0x2E, 0x11: 0x2D, 0x12: 0x1F, 0x13: 0x23,
        0x14: 0x0C, 0x15: 0x0F, 0x16: 0x01, 0x17: 0x11, 0x18: 0x20, 0x19: 0x09, 0x1A: 0x0D, 0x1B: 0x07,
        0x1C: 0x10, 0x1D: 0x06,
        // Digits 1–9, 0
        0x1E: 0x12, 0x1F: 0x13, 0x20: 0x14, 0x21: 0x15, 0x22: 0x17, 0x23: 0x16, 0x24: 0x1A, 0x25: 0x1C,
        0x26: 0x19, 0x27: 0x1D,
        // Return, Escape, Delete, Tab, Space, punctuation
        0x28: 0x24, 0x29: 0x35, 0x2A: 0x33, 0x2B: 0x30, 0x2C: 0x31, 0x2D: 0x1B, 0x2E: 0x18, 0x2F: 0x21,
        0x30: 0x1E, 0x31: 0x2A, 0x33: 0x29, 0x34: 0x27, 0x35: 0x32, 0x36: 0x2B, 0x37: 0x2F, 0x38: 0x2C,
        0x39: 0x39,
        // F1–F12
        0x3A: 0x7A, 0x3B: 0x78, 0x3C: 0x63, 0x3D: 0x76, 0x3E: 0x60, 0x3F: 0x61, 0x40: 0x62, 0x41: 0x64,
        0x42: 0x65, 0x43: 0x6D, 0x44: 0x67, 0x45: 0x6F,
        // Help (Insert), Home, Page Up, Forward Delete, End, Page Down, arrows
        0x49: 0x72, 0x4A: 0x73, 0x4B: 0x74, 0x4C: 0x75, 0x4D: 0x77, 0x4E: 0x79,
        0x4F: 0x7C, 0x50: 0x7B, 0x51: 0x7D, 0x52: 0x7E,
        // Keypad
        0x53: 0x47, 0x54: 0x4B, 0x55: 0x43, 0x56: 0x4E, 0x57: 0x45, 0x58: 0x4C, 0x59: 0x53, 0x5A: 0x54,
        0x5B: 0x55, 0x5C: 0x56, 0x5D: 0x57, 0x5E: 0x58, 0x5F: 0x59, 0x60: 0x5B, 0x61: 0x5C, 0x62: 0x52,
        0x63: 0x41, 0x67: 0x51,
        // ISO section key, F13–F20
        0x64: 0x0A, 0x68: 0x69, 0x69: 0x6B, 0x6A: 0x71, 0x6B: 0x6A, 0x6C: 0x40, 0x6D: 0x4F, 0x6E: 0x50,
        0x6F: 0x5A,
        // JIS: Ro, Yen, Kana, Eisu
        0x87: 0x5E, 0x89: 0x5D, 0x90: 0x68, 0x91: 0x66,
        // Modifiers: left Control, Shift, Option, Command, then right
        0xE0: 0x3B, 0xE1: 0x38, 0xE2: 0x3A, 0xE3: 0x37, 0xE4: 0x3E, 0xE5: 0x3C, 0xE6: 0x3D, 0xE7: 0x36,
    ]
}

/// System shortcuts a device may not send, because they reach past the shared window to the rest of
/// the Mac (Spotlight, the app switcher, Force Quit, Lock Screen, Log Out, Mission Control, Spaces and
/// keyboard navigation). A second line of defence: keys are posted to the shared app's process, which
/// already keeps them away from system-wide shortcuts.
/// Every key works on its own and with Shift or Option alone, so typing is never affected.
public enum ShortcutPolicy {
    public static func allows(usage: UInt16, modifiers: Modifiers) -> Bool {
        typealias U = HIDKeyMap.Usage
        let m = modifiers
        switch usage {
        case U.space where m.contains(.command):
            return false // Spotlight, Finder search
        case U.tab where m.contains(.command):
            return false // app switcher
        case U.escape where m.isSuperset(of: [.command, .option]):
            return false // Force Quit
        case HIDKeyMap.Usage.q where m.isSuperset(of: [.command, .control]):
            return false // Lock Screen
        case HIDKeyMap.Usage.q where m.isSuperset(of: [.command, .shift]):
            return false // Log Out
        case let key where m.contains(.control) && HIDKeyMap.isFunctionKey(key):
            return false // keyboard navigation: menu bar, Dock, window cycling
        // One `where` per pattern: on a shared case it would guard only the last one.
        case U.leftArrow where m.contains(.control), U.rightArrow where m.contains(.control),
             U.upArrow where m.contains(.control), U.downArrow where m.contains(.control):
            return false // Mission Control, App Exposé, Spaces
        default:
            return true
        }
    }
}
