import Foundation

public enum ReviewCommand {
    public static func expand(_ template: String, url: String, repo: String, number: Int) -> String {
        template
            .replacingOccurrences(of: "{url}", with: url)
            .replacingOccurrences(of: "{repo}", with: repo)
            .replacingOccurrences(of: "{number}", with: String(number))
    }
}
