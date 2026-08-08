import SwiftUI

extension Color {
        static var textBackgroundColor: Color { Color(nsColor: NSColor.textBackgroundColor) }
        static var textColor: Color { Color(nsColor: NSColor.textColor) }
}

extension ColorScheme {
        var isLight: Bool { self == .light }
        var isDark: Bool { self == .dark }

        var blue    : Color { isLight ? LightTheme.blue     : DarkTheme.blue     }
        var purple  : Color { isLight ? LightTheme.purple   : DarkTheme.purple   }
        var pink    : Color { isLight ? LightTheme.pink     : DarkTheme.pink     }
        var red     : Color { isLight ? LightTheme.red      : DarkTheme.red      }
        var orange  : Color { isLight ? LightTheme.orange   : DarkTheme.orange   }
        var yellow  : Color { isLight ? LightTheme.yellow   : DarkTheme.yellow   }
        var green   : Color { isLight ? LightTheme.green    : DarkTheme.green    }
        var graphite: Color { isLight ? LightTheme.graphite : DarkTheme.graphite }
}

private struct LightTheme {
        static let blue    : Color = Color(r:   0, g: 122, b: 255) // #007AFF
        static let purple  : Color = Color(r: 149, g:  61, b: 150) // #953D96
        static let pink    : Color = Color(r: 247, g:  79, b: 158) // #F74F9E
        static let red     : Color = Color(r: 224, g:  56, b:  62) // #E0383E
        static let orange  : Color = Color(r: 247, g: 130, b:  27) // #F7821B
        static let yellow  : Color = Color(r: 255, g: 199, b:  38) // #FFC726
        static let green   : Color = Color(r:  98, g: 186, b:  70) // #62BA46
        static let graphite: Color = Color(r: 152, g: 152, b: 152) // #989898
}

private struct DarkTheme {
        static let blue    : Color = Color(r:   0, g: 122, b: 255) // #007AFF
        static let purple  : Color = Color(r: 165, g:  80, b: 167) // #A550A7
        static let pink    : Color = Color(r: 247, g:  79, b: 158) // #F74F9E
        static let red     : Color = Color(r: 255, g:  82, b:  87) // #FF5257
        static let orange  : Color = Color(r: 247, g: 130, b:  27) // #F7821B
        static let yellow  : Color = Color(r: 255, g: 198, b:   0) // #FFC600
        static let green   : Color = Color(r:  98, g: 186, b:  70) // #62BA46
        static let graphite: Color = Color(r: 140, g: 140, b: 140) // #8C8C8C
}

private extension Color {
        init(r: Double, g: Double, b: Double) {
                let red = r / 255.0
                let green = g / 255.0
                let blue = b / 255.0
                self.init(red: red, green: green, blue: blue)
        }
}
