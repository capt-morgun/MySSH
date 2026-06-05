import SwiftUI
import Combine

class AppearanceSettings: ObservableObject {
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    @Published var textColorRGB: [Double]
    @Published var bgColorRGB: [Double]
    @Published var accentColorRGB: [Double]
    @Published var groupColorRGB: [Double]
    @Published var fontName: String
    @Published var fontSize: Double
    @Published var fontBold: Bool
    @Published var groupFontSize: Double
    @Published var groupFontBold: Bool

    var textColor: Color {
        get { Color(red: textColorRGB[0], green: textColorRGB[1], blue: textColorRGB[2]) }
        set { textColorRGB = newValue.rgbComponents }
    }

    var backgroundColor: Color {
        get { Color(red: bgColorRGB[0], green: bgColorRGB[1], blue: bgColorRGB[2]) }
        set { bgColorRGB = newValue.rgbComponents }
    }

    var accentColor: Color {
        get { Color(red: accentColorRGB[0], green: accentColorRGB[1], blue: accentColorRGB[2]) }
        set { accentColorRGB = newValue.rgbComponents }
    }

    var groupHeaderColor: Color {
        get { Color(red: groupColorRGB[0], green: groupColorRGB[1], blue: groupColorRGB[2]) }
        set { groupColorRGB = newValue.rgbComponents }
    }

    var contentFont: Font {
        let base: Font = fontName == "System"
            ? .system(size: CGFloat(fontSize))
            : .custom(fontName, size: CGFloat(fontSize))
        return fontBold ? base.bold() : base
    }

    var groupFont: Font {
        let base: Font = fontName == "System"
            ? .system(size: CGFloat(groupFontSize))
            : .custom(fontName, size: CGFloat(groupFontSize))
        return groupFontBold ? base.bold() : base
    }

    var detailFont: Font {
        let base: Font = fontName == "System"
            ? .system(size: CGFloat(fontSize))
            : .custom(fontName, size: CGFloat(fontSize))
        return base
    }

    init() {
        textColorRGB = Self.load("textColor") ?? [1, 1, 1]
        bgColorRGB = Self.load("bgColor") ?? [0.15, 0.15, 0.15]
        accentColorRGB = Self.load("accentColor") ?? [0.0, 0.48, 1.0]
        groupColorRGB = Self.load("groupColor") ?? [1.0, 0.6, 0.0]
        fontName = UserDefaults.standard.string(forKey: "fontName") ?? "System"
        fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 13
        fontBold = UserDefaults.standard.bool(forKey: "fontBold")
        groupFontSize = UserDefaults.standard.object(forKey: "groupFontSize") as? Double ?? 14
        groupFontBold = UserDefaults.standard.object(forKey: "groupFontBold") == nil ? true : UserDefaults.standard.bool(forKey: "groupFontBold")

        $textColorRGB.sink { [weak self] v in self?.save(v, key: "textColor") }.store(in: &cancellables)
        $bgColorRGB.sink { [weak self] v in self?.save(v, key: "bgColor") }.store(in: &cancellables)
        $accentColorRGB.sink { [weak self] v in self?.save(v, key: "accentColor") }.store(in: &cancellables)
        $groupColorRGB.sink { [weak self] v in self?.save(v, key: "groupColor") }.store(in: &cancellables)
        $fontName.sink { [weak self] v in self?.defaults.set(v, forKey: "fontName") }.store(in: &cancellables)
        $fontSize.sink { [weak self] v in self?.defaults.set(v, forKey: "fontSize") }.store(in: &cancellables)
        $fontBold.sink { [weak self] v in self?.defaults.set(v, forKey: "fontBold") }.store(in: &cancellables)
        $groupFontSize.sink { [weak self] v in self?.defaults.set(v, forKey: "groupFontSize") }.store(in: &cancellables)
        $groupFontBold.sink { [weak self] v in self?.defaults.set(v, forKey: "groupFontBold") }.store(in: &cancellables)
    }

    func resetToDefaults() {
        textColorRGB = [1, 1, 1]
        bgColorRGB = [0.15, 0.15, 0.15]
        accentColorRGB = [0.0, 0.48, 1.0]
        groupColorRGB = [1.0, 0.6, 0.0]
        fontName = "System"
        fontSize = 13
        fontBold = false
        groupFontSize = 14
        groupFontBold = true
    }

    static var availableFonts: [String] {
        ["System"] + NSFontManager.shared.availableFontFamilies.sorted()
    }

    private func save(_ rgb: [Double], key: String) {
        defaults.set(rgb, forKey: key)
    }

    private static func load(_ key: String) -> [Double]? {
        UserDefaults.standard.array(forKey: key) as? [Double]
    }
}

extension Color {
    var rgbComponents: [Double] {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(red: 0, green: 0, blue: 0, alpha: 1)
        return [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)]
    }
}
