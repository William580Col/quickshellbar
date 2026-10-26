import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._ToplevelManagement
import "../config"
import "../services" as Services

/*
  Barra superior/inferior, controlada por config/BarConfig.qml: posición,
  auto-ocultar, escala, módulos habilitados/orden/zona, y efecto cristal.
  Se instancia una por cada pantalla desde shell.qml.

  NOTA sobre auto-ocultar: al ocultarse, la ventana se reduce a una franja
  sensora de 6px (sin animación de deslizamiento — animar el tamaño real de
  una superficie layer-shell cuadro a cuadro es delicado entre compositores,
  así que se prefirió un cambio directo, simple y confiable). Pasar el mouse
  por esa franja la vuelve a mostrar.
*/
PanelWindow {
    id: bar

    required property var modelData // pantalla (screen) inyectada por Variants
    screen: modelData

    property var launcherRef
    property var powerMenuRef
    property var clipRef
    property var wallpaperRef
    property var wifiPanelRef
    property var bluetoothPanelRef
    property var barSettingsRef

    // Namespace de la superficie, para poder apuntarle con una regla de
    // Hyprland (hl.layer_rule) y lograr blur real además de la transparencia
    // que ya aplicamos nosotros mismos. Ver README, sección "Efecto cristal".
    WlrLayershell.namespace: "quickshell"

    anchors {
        top: BarConfig.position === "top"
        bottom: BarConfig.position === "bottom"
        left: true
        right: true
    }

    property real fullHeight: Theme.barHeight * BarConfig.scale + 12
    property bool hidden: false
    // Cuando hay una ventana fullscreen en esta pantalla, la barra se oculta
    // para que la ventana ocupé todo el output (p. ej. Firefox F11).
    property bool fullscreenBlocking: false

    implicitHeight: (hidden || fullscreenBlocking) ? 6 : fullHeight
    exclusiveZone: (hidden || fullscreenBlocking) ? 0 : fullHeight
    color: "transparent"

    function revealBar() {
        hideTimer.stop()
        bar.hidden = false
    }
    function scheduleHide() {
        if (BarConfig.autoHide) hideTimer.restart()
    }
    onVisibleChanged: if (BarConfig.autoHide) hideTimer.restart()
    Connections {
        target: BarConfig
        function onAutoHideChanged() {
            if (!BarConfig.autoHide) bar.hidden = false
            else hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: bar.hidden = true
    }

    // Detecta ventanas fullscreen en esta pantalla y oculta la barra para
    // que la ventana ocupé todo el output. Se verifica periódicamente (respaldo)
    // y también ante cambios de fullscreen de cada toplevel.
    Timer {
        id: fullscreenPollTimer
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.updateFullscreenBlocking()
    }

    ListView {
        id: fullscreenDetector
        model: ToplevelManager.toplevels
        width: 0
        height: 0
        delegate: Item {
            Connections {
                target: modelData
                onFullscreenChanged: bar.updateFullscreenBlocking()
            }
            Component.onCompleted: bar.updateFullscreenBlocking()
        }
    }

    function updateFullscreenBlocking() {
        var blocking = false
        var vals = ToplevelManager.toplevels.values
        for (var i = 0; i < vals.length; i++) {
            var tl = vals[i]
            if (!tl || tl.minimized) continue
            if (tl.fullscreen && tl.screens.indexOf(bar.screen) >= 0) {
                blocking = true
                break
            }
        }
        fullscreenBlocking = blocking
    }

    // Detector de hover para todo el área de la barra (incluida la franja
    // sensora cuando está oculta). No intercepta clics (acceptedButtons:
    // NoButton), solo detecta presencia del mouse.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: bar.revealBar()
        onExited: bar.scheduleHide()
    }

    // Fondo de la barra: una "pastilla" flotante con margen y bordes
    // redondeados. Con "efecto cristal" activo, se vuelve translúcida.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: Theme.radiusLarge
        color: BarConfig.surfaceColor(Theme.bg)
        border.color: Theme.border
        border.width: 1
        visible: !bar.hidden
        opacity: bar.hidden ? 0 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 16

            // ---------------- IZQUIERDA ----------------
            RowLayout {
                spacing: 14
                Repeater {
                    model: BarConfig.modulesForZone("left")
                    delegate: Loader {
                        required property var modelData
                        sourceComponent: bar.moduleComponents[modelData.id]
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // ---------------- CENTRO ----------------
            RowLayout {
                spacing: 14
                Repeater {
                    model: BarConfig.modulesForZone("center")
                    delegate: Loader {
                        required property var modelData
                        sourceComponent: bar.moduleComponents[modelData.id]
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // ---------------- DERECHA ----------------
            RowLayout {
                spacing: 14
                Repeater {
                    model: BarConfig.modulesForZone("right")
                    delegate: Loader {
                        required property var modelData
                        sourceComponent: bar.moduleComponents[modelData.id]
                    }
                }
            }
        }
    }

    // ================= Mapa id de módulo -> componente visual =================
    property var moduleComponents: ({
        "launcher": launcherComponent,
        "workspaces": workspacesComponent,
        "activewindow": activeWindowComponent,
        "clock": clockComponent,
        "tray": trayComponent,
        "screenshot": screenshotComponent,
        "wifi": wifiComponent,
        "bluetooth": bluetoothComponent,
        "volume": volumeComponent,
        "quicksettings": quickSettingsButtonComponent,
        "wallpaper": wallpaperComponent,
        "clipboard": clipboardComponent,
        "barsettings": barSettingsComponent,
        "hidebar": hideBarComponent,
        "power": powerComponent,
    })

    Component {
        id: launcherComponent
        Rectangle {
            width: 30
            height: 30
            radius: Theme.radiusMedium
            color: launcherArea.containsMouse ? Theme.bgAlt : "transparent"
            Text {
                anchors.centerIn: parent
                text: "󰀻"
                color: Theme.accent
                font.pixelSize: 16
            }
            MouseArea {
                id: launcherArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.launcherRef && bar.launcherRef.toggle()
            }
        }
    }

    Component { id: workspacesComponent; Workspaces {} }
    Component { id: activeWindowComponent; ActiveWindow {} }

    Component {
        id: clockComponent
        Clock {
            onClicked: calendarPopup.visible = !calendarPopup.visible
        }
    }

    Component { id: trayComponent; Tray {} }
    Component { id: screenshotComponent; Screenshot {} }

    Component {
        id: wifiComponent
        Item {
            width: wifiIcon.implicitWidth
            height: 30
            Text {
                id: wifiIcon
                anchors.centerIn: parent
                text: Services.Network.status === "wifi" ? "󰤨" : (Services.Network.status === "ethernet" ? "󰈀" : "󰤮")
                color: Theme.text; font.pixelSize: 14
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.wifiPanelRef && bar.wifiPanelRef.toggle()
            }
        }
    }

    Component {
        id: bluetoothComponent
        Item {
            width: btIcon.implicitWidth
            height: 30
            Text {
                id: btIcon
                anchors.centerIn: parent
                text: Services.Bluetooth.powered
                    ? (Services.Bluetooth.anyConnected ? "󰂱" : "󰂯")
                    : "󰂲"
                color: Services.Bluetooth.anyConnected
                    ? Theme.accent
                    : (Services.Bluetooth.powered ? Theme.text : Theme.subtext)
                font.pixelSize: 14
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.bluetoothPanelRef && bar.bluetoothPanelRef.toggle()
            }
        }
    }

    Component {
        id: volumeComponent
        Item {
            width: volText.implicitWidth
            height: 30
            Text {
                id: volText
                anchors.centerIn: parent
                text: Services.Audio.muted ? "󰝟"
                      : (Services.Audio.volume > 0.66 ? "󰕾"
                      : (Services.Audio.volume > 0.33 ? "󰖀"
                      : (Services.Audio.volume > 0 ? "󰕿" : "󰝟")))
                color: Theme.text; font.pixelSize: 14
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Audio.toggleMute()
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) Services.Audio.increase(0.05)
                    else if (wheel.angleDelta.y < 0) Services.Audio.decrease(0.05)
                }
            }
        }
    }

    Component {
        id: quickSettingsButtonComponent
        Text {
            text: "󰒓"
            color: Theme.text
            font.pixelSize: 14
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: quickSettingsPopup.visible = !quickSettingsPopup.visible
            }
        }
    }

    Component {
        id: wallpaperComponent
        Text {
            text: "󰸉"
            color: Theme.text
            font.pixelSize: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.wallpaperRef && bar.wallpaperRef.toggle()
            }
        }
    }

    Component {
        id: clipboardComponent
        Text {
            text: "󰅍"
            color: Theme.text
            font.pixelSize: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.clipRef && bar.clipRef.toggle()
            }
        }
    }

    Component {
        id: barSettingsComponent
        Text {
            text: "󰢻"
            color: Theme.text
            font.pixelSize: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.barSettingsRef && bar.barSettingsRef.toggle()
            }
        }
    }

    Component {
        id: hideBarComponent
        Text {
            text: BarConfig.autoHide ? "" : ""
            color: BarConfig.autoHide ? Theme.accent : Theme.subtext
            font.pixelSize: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: BarConfig.setAutoHide(!BarConfig.autoHide)
            }
        }
    }

    Component {
        id: powerComponent
        Text {
            text: "󰐥"
            color: Theme.danger
            font.pixelSize: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.powerMenuRef && bar.powerMenuRef.toggle()
            }
        }
    }

    // ---------- Popups flotantes anclados a la barra ----------
    PopupWindow {
        id: calendarPopup
        anchor.window: bar
        anchor.rect.x: bar.width / 2 - 130
        anchor.rect.y: BarConfig.position === "top" ? bar.fullHeight - 2 : -300 - 8
        implicitWidth: 260
        implicitHeight: 300
        visible: false
        color: "transparent"
        Calendar { anchors.fill: parent }
    }

    PopupWindow {
        id: quickSettingsPopup
        anchor.window: bar
        anchor.rect.x: bar.width - 340
        anchor.rect.y: BarConfig.position === "top" ? bar.fullHeight - 2 : -420 - 8
        implicitWidth: 320
        implicitHeight: 420
        visible: false
        color: "transparent"
        QuickSettings {
            anchors.fill: parent
            onWifiRequested: {
                quickSettingsPopup.visible = false
                bar.wifiPanelRef && bar.wifiPanelRef.toggle()
            }
        }
    }
}
