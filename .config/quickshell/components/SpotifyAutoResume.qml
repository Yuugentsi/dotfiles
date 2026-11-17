pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Scope {
    Component.onCompleted: console.info("Spotify auto-resume active")

    Variants {
        model: Mpris.players.values
        delegate: Scope {
            id: watcher
            required property var modelData
            readonly property bool isSpotify: /^org\.mpris\.MediaPlayer2\.spotify(?:\.|$)/i.test(String(modelData.dbusName || "")) || String(modelData.identity || "").toLowerCase() === "spotify"
            readonly property bool shouldResume: isSpotify && modelData.canPlay && modelData.playbackState === MprisPlaybackState.Paused

            Timer {
                interval: 250
                running: watcher.shouldResume
                repeat: true
                onTriggered: {
                    if (watcher.shouldResume) {
                        watcher.modelData.play();
                        console.info("Spotify auto-resume requested");
                    }
                }
            }
        }
    }
}
