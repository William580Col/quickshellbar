import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    property var windowSwitcherRef

    // Namespace de la superficie layer-shell. NOTA Sway: Sway no soporta
    // blur de capas por diseño; solo usamos transparencia propia
    // (BarConfig.surfaceColor con alpha 0.82) sobre PanelWindow transparente.
    WlrLayershell.namespace: "quickshell"

    // Capa Overlay: garantía DETERMINISTA de apilado entre la barra y el
    // marco (ScreenFrame, capa Top). Con ambas en Top el orden lo decide el
    // mapeo de las superficies, y eso no es fiable: quickshell reutiliza la
    // ventana física al recargar la config (ProxyWindowBase::onReload →
    // retrieveWindow) conservando el apilado antiguo, y cada ocultar/
    // re-mostrar recrea la superficie (WlrLayershell.deleteOnInvisible) y la
    // pone por encima de su misma capa. Overlay > Top por protocolo: los
    // iconos quedan SIEMPRE por encima de la banda opaca que pinta el marco,
    // sin depender del orden de creación. Sin efectos secundarios: ninguna
    // otra ventana Top de quickshell solapa la franja de la barra
    // (notificaciones arrancan en y=50, dock abajo, marco transparente aquí),
    // y las zonas exclusivas/entradas no dependen de la capa.
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: BarConfig.position === "top"
        bottom: BarConfig.position === "bottom"
        left: true
        right: true
    }

    // Alto compartido de la ventana (ya redondeado a píxel en BarConfig):
    // no se recalcula aquí para no divergir de la geometría del marco.
    property real fullHeight: BarConfig.barWindowHeight
    // Borde inferior de la superficie visible de la barra: mismo alto que
    // la pastilla clásica (sin el margen inferior de6px). Así la barra no
    // se ve "grande" y deja6px de aire antes del área de contenido.
    readonly property real surfaceBottom: BarConfig.barSurfaceEdge
    // Superficie a sangre según posición: arriba = y0..surfaceBottom (tocando
    // el borde superior); abajo = y6..fullHeight (tocando el inferior). La
    // banda del marco cubre sus bordes contra la pantalla, así que el
    // rectángulo no necesita redondeo propio.
    readonly property real surfTop: BarConfig.position === "top" ? 0 : 6
    readonly property real surfEnd: BarConfig.position === "top" ? surfaceBottom : fullHeight
    property bool hidden: false
    // Cuando hay una ventana fullscreen en esta pantalla, la barra se oculta
    // para que la ventana ocupé todo el output (p. ej. Firefox F11).
    property bool fullscreenBlocking: false

    implicitHeight: (hidden || fullscreenBlocking) ? 6 : fullHeight
    // Zona exclusiva = alto visual de la barra (surfaceBottom), no el alto
    // de ventana (fullHeight). Así las ventanas maximizadas empiezan justo
    // debajo de la banda, igual que abajo con el dock (exclusiveZone 0),
    // sin gap de 6px de diferencia entre arriba y abajo.
    exclusiveZone: (hidden || fullscreenBlocking) ? 0 : surfaceBottom
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
        running: true
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
                function onFullscreenChanged() {
                    bar.updateFullscreenBlocking()
                }
            }
            Component.onCompleted: bar.updateFullscreenBlocking()
        }
    }

    function updateFullscreenBlocking() {
        var blocking = false
        var vals = ToplevelManager.toplevels.values
        for (var i = 0; i < vals.length; i++) {
            var tl = vals[i]
            if (!tl || tl.minimized || !tl.fullscreen) continue
            var onScreen = false
            var scrs = tl.screens || []
            for (var j = 0; j < scrs.length; j++) {
                if (scrs[j] && bar.screen && scrs[j].name === bar.screen.name) {
                    onScreen = true
                    break
                }
            }
            if (onScreen) {
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

    // ---- Superficie Caelestia (detrás del contenido) ----
    // Rectángulo opaco a sangre hasta surfaceBottom, con MSAA
    // (layer.samples: 4) + antialiasing para bordes suaves.
    // SOLO pinta la banda cuando NO la pinta el marco: con el marco
    // activo (screenBorder + estilo Caelestia) el único pintor de la
    // unión barra↔fillet↔filete es ScreenFrame, que los resuelve en su
    // propio buffer con el mismo MSAA (aquí solo se apaga ESTE fondo;
    // la ventana sigue transparente y los hijos de arriba —iconos y
    // módulos— siguen visibles encima de la banda que pinta el marco).
    // Sin contorno propio: el filete del marco más el contraste
    // blanco/oscuro dibujan el perfil, igual que con paneles integrados.
    Shape {
        visible: !bar.hidden && !bar.fullscreenBlocking && BarConfig.screenBorder && !BarConfig.caelestia
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true
        layer.samples: 4

        // Rectángulo a sangre (ver surfTop/surfEnd): sin redondeo propio,
        // la banda del marco define las esquinas de la pantalla y cubre los
        // bordes pegados a ella.
        ShapePath {
            fillColor: Theme.bg
            strokeColor: "transparent"

            PathMove { x: 0; y: bar.surfTop }
            PathLine { x: bar.width; y: bar.surfTop }
            PathLine { x: bar.width; y: bar.surfEnd }
            PathLine { x: 0; y: bar.surfEnd }
        }
    }

    // Fondo de la barra. En estilo "clásico" es una pastilla flotante con
    // margen y bordes redondeados (con "efecto cristal", translúcida). Con
    // el marco de pantalla (Caelestia) queda transparente y sin borde: es
    // solo el contenedor de layout; la superficie la dibuja el Shape de
    // arriba, que sí llega al borde de la pantalla.
    Rectangle {
        id: bg
        // Sin margen en el lado pegado a la pantalla: el contenido se centra
        // en la superficie real cuando la barra va a sangre (arriba: sin
        // margen superior; abajo: sin margen inferior).
        anchors.fill: parent
        anchors.margins: 6
        anchors.topMargin: BarConfig.screenBorder && BarConfig.position === "top" ? 0 : 6
        anchors.bottomMargin: BarConfig.screenBorder && BarConfig.position === "bottom" ? 0 : 6
        radius: Theme.radiusLarge
        color: BarConfig.screenBorder ? "transparent" : BarConfig.surfaceColor(Theme.bg)
        border.color: Theme.border
        border.width: BarConfig.screenBorder ? 0 : 1
        visible: !bar.hidden && !bar.fullscreenBlocking
        opacity: (bar.hidden || bar.fullscreenBlocking) ? 0 : 1

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
        "windowswitcher": windowSwitcherComponent,
        "clock": clockComponent,
        "mediacontrols": mediaControlsComponent,
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
    Component { id: mediaControlsComponent; MediaControls {} }

    Component {
        id: windowSwitcherComponent
        Text {
            text: "󱂬"
            color: Theme.text
            font.pixelSize: 15
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.windowSwitcherRef && bar.windowSwitcherRef.toggle()
            }
        }
    }

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
        // Integrado: pegado al borde inferior visible de la barra (1px de
        // solape). Clásico: 2px bajo la barra, u 8px sobre ella si la
        // barra está abajo.
        anchor.rect.y: BarConfig.integratedPanels
            ? (BarConfig.position === "top" ? bar.fullHeight - 7 : 7 - implicitHeight)
            : (BarConfig.position === "top" ? bar.fullHeight - 2 : -implicitHeight - 8)
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
        // Igual que calendarPopup: integrado pegado a la barra, clásico como antes.
        anchor.rect.y: BarConfig.integratedPanels
            ? (BarConfig.position === "top" ? bar.fullHeight - 7 : 7 - implicitHeight)
            : (BarConfig.position === "top" ? bar.fullHeight - 2 : -implicitHeight - 8)
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
