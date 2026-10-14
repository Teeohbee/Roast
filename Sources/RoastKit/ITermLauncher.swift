import Foundation

public enum ITermLauncher {
    private static let script = """
    on run argv
      tell application "iTerm2"
        if (count of windows) = 0 then create window with default profile
        tell current window
          set previousTab to current tab
          set newTab to (create tab with default profile)
          tell current session of newTab to write text (item 1 of argv)
          select previousTab
        end tell
      end tell
    end run
    """

    public static func open(command: String, onFailure: @escaping @Sendable (String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, command]
        let stderr = Pipe()
        process.standardError = stderr
        process.terminationHandler = { finished in
            guard finished.terminationStatus != 0 else { return }
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            onFailure(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        do {
            try process.run()
        } catch {
            onFailure(error.localizedDescription)
        }
    }
}
