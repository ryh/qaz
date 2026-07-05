import Foundation

enum AssetSelector {
    static func select(from assets: [Asset]) -> Asset? {
        guard !assets.isEmpty else {
            return nil
        }

        print("")
        for (index, asset) in assets.enumerated() {
            let num = Color.bold("\(index + 1).")
            let name = asset.name
            var parts: [String] = []

            if asset.isRecommended {
                parts.append(Color.green("*"))
            }

            if !asset.platformHint.isEmpty {
                let hint = Color.cyan("[\(asset.platformHint)]")
                parts.append(hint)
            }

            if !asset.architectureHint.isEmpty {
                let arch = Color.yellow("(\(asset.architectureHint))")
                parts.append(arch)
            }

            let size = Color.dim(asset.formattedSize)
            let meta = parts.isEmpty ? size : "\(parts.joined(separator: " ")) \(size)"

            print("  \(num) \(name) \(meta)")
        }

        print("")
        print("  \(Color.green("*")) = recommended for your system")
        print("  \(Color.dim("0")) = cancel")
        print("")

        while true {
            print("Select asset (1-\(assets.count)): ", terminator: "")
            fflush(stdout)

            guard let input = readLine(), let choice = Int(input) else {
                print(Color.red("Invalid input. Please enter a number."))
                continue
            }

            if choice == 0 {
                return nil
            }

            if choice >= 1 && choice <= assets.count {
                return assets[choice - 1]
            }

            print(Color.red("Invalid choice. Please enter 1-\(assets.count)."))
        }
    }
}
