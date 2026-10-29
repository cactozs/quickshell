pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Particles
import "../style"

// Seasonal desktop dressing for ShellState.ambient === "xmas": snow falling
// over the wallpaper. Lives in the existing full-screen wallpaper surface
// and never takes input.
Item {
    // A few dim candle-like points add a warm holiday accent without another
    // animated full-screen effect.
    Repeater {
        model: [0.14, 0.53, 0.88]

        delegate: Rectangle {
            required property real modelData

            x: parent.width * modelData
            y: parent.height - 12
            width: 4
            height: width
            radius: width / 2
            color: Theme.candle
            opacity: 0.48
        }
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
            emitRate: Math.max(0.45, Math.min(1.2, parent.width / 1500))
            lifeSpan: 12500
            lifeSpanVariation: 2500
            size: 5
            sizeVariation: 3

            velocity: AngleDirection {
                angle: 90
                angleVariation: 8
                magnitude: 55
                magnitudeVariation: 25
            }

            acceleration: PointDirection {
                y: 2
            }
        }

        Wander {
            xVariance: 28
            yVariance: 0
            pace: 0.16
        }

        ImageParticle {
            // Qt's built-in soft dot: white, so `color` can tint it.
            source: "qrc:///particleresources/fuzzydot.png"
            color: Theme.snow
            alpha: 0.85
            alphaVariation: 0.2
        }
    }
}
