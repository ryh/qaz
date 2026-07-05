import Foundation

enum Color {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"

    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let cyan = "\u{001B}[36m"

    static func supportColor() -> Bool {
        guard let term = ProcessInfo.processInfo.environment["TERM"],
              term != "dumb" else {
            return false
        }
        return isatty(STDOUT_FILENO) != 0
    }

    static let enabled = supportColor()

    static func colored(_ text: String, _ color: String) -> String {
        enabled ? "\(color)\(text)\(reset)" : text
    }

    static func bold(_ text: String) -> String {
        enabled ? "\(bold)\(text)\(reset)" : text
    }

    static func dim(_ text: String) -> String {
        enabled ? "\(dim)\(text)\(reset)" : text
    }

    static func green(_ text: String) -> String {
        colored(text, green)
    }

    static func red(_ text: String) -> String {
        colored(text, red)
    }

    static func yellow(_ text: String) -> String {
        colored(text, yellow)
    }

    static func blue(_ text: String) -> String {
        colored(text, blue)
    }

    static func cyan(_ text: String) -> String {
        colored(text, cyan)
    }
}
