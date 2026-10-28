pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Particles
import "../style"

// Seasonal desktop dressing for ShellState.ambient === "xmas": snow falling
// over the wallpaper and drifts along the bottom edge. Lives in the existing
// full-screen wallpaper surface (WallpaperDrop), so it stays under windows and
// never takes input.
Item {
    // Drifts: top halves of wide rounded rectangles, so only the mounds show.
    Repeater {
        model: [
            { x: -0.04, w: 0.26, h: 22 },
            { x: 0.20, w: 0.18, h: 12 },
            { x: 0.40, w: 0.24, h: 17 },
            { x: 0.64, w: 0.16, h: 10 },
            { x: 0.82, w: 0.26, h: 20 }
        ]

        delegate: Rectangle {
            required property var modelData

            x: parent.width * modelData.x
            y: parent.height - height / 2
            width: parent.width * modelData.w
            height: modelData.h
            radius: height / 2
            color: Theme.snow
            opacity: 0.9
            antialiasing: true
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        height: 4
        radius: 2
        color: Theme.snow
        opacity: 0.9
        antialiasing: true
    }

    // Opt-in: an animated full-screen layer repaints at the compositor rate,
    // so it costs more than the static shell while enabled.
    ParticleSystem {
        anchors.fill: parent

        Emitter {
            x: 0
            y: -20
            width: parent.width
            height: 1
            emitRate: 4
            lifeSpan: 20000
            lifeSpanVariation: 6000
            size: 7
            sizeVariation: 5

            velocity: AngleDirection {
                angle: 90
                angleVariation: 8
                magnitude: 60
                magnitudeVariation: 30
            }

            acceleration: PointDirection {
                y: 2
            }
        }

        Wander {
            xVariance: 50
            yVariance: 0
            pace: 0.2
        }

        ImageParticle {
            // Qt's built-in soft dot: white, so `color` can tint it.
            source: "qrc:///particleresources/fuzzydot.png"
            color: Theme.snow
            alpha: 0.85
        }
    }
}
