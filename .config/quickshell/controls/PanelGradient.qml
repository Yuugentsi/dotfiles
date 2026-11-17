import QtQuick
import "PanelTheme.js" as Theme

Gradient {
    GradientStop {
        position: 0
        color: Theme.gradientTop
    }
    GradientStop {
        position: 0.45
        color: Theme.gradientMiddle
    }
    GradientStop {
        position: 1
        color: Theme.gradientBottom
    }
}
