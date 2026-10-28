pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Particles
import "../style"

// Seasonal desktop dressing for ShellState.ambient === "xmas": snow falling
// over the wallpaper and drifts along the bottom edge. Lives in the existing
// full-screen wallpaper surface (WallpaperDrop), so it stays under windows and
// never takes input.
Item {
    // A shallow frost tint grounds the snow without making a hard horizon.
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 28
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(Theme.snow.r, Theme.snow.g, Theme.snow.b, 0)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.snow.r, Theme.snow.g, Theme.snow.b, 0.12)
            }
        }
    }

    // Overlapping rounded mounds make a scalloped, low snowline.
    Repeater {
        model: [
            { x: -0.04, w: 0.26, h: 15 },
            { x: 0.20, w: 0.18, h: 9 },
            { x: 0.40, w: 0.24, h: 12 },
            { x: 0.64, w: 0.16, h: 8 },
            { x: 0.82, w: 0.26, h: 14 }
        ]

        delegate: Item {
            required property var modelData

            x: parent.width * modelData.x
            width: parent.width * modelData.w
            height: modelData.h
            y: parent.height - height
            opacity: 0.55

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.55
                radius: height / 2
                color: Theme.snow
                antialiasing: true
            }

            Rectangle {
                x: parent.width * 0.2
                y: parent.height * 0.28
                width: parent.height * 0.72
                height: width
                radius: width / 2
                color: Theme.snow
                antialiasing: true
            }

            Rectangle {
                x: parent.width * 0.62
                y: parent.height * 0.38
                width: parent.height * 0.58
                height: width
                radius: width / 2
                color: Theme.snow
                antialiasing: true
            }
        }
    }

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
            property real pulse
            opacity: 0.35 + pulse * 0.4

            SequentialAnimation on pulse {
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 1800 }
                NumberAnimation { to: 0; duration: 2300 }
            }
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
            emitRate: Math.max(0.7, Math.min(2, parent.width / 900))
            lifeSpan: 16000
            lifeSpanVariation: 4000
            size: 6
            sizeVariation: 5

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
