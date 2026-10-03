import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "WindowModel.js" as WindowModel
import qs.Commons

// Mission Control's Spaces bar: one miniature desktop per workspace on this
// screen, windows placed where they sit. Clicking one goes to it; dropping a
// dragged window on one moves the window there.
Item {
    id: strip

    required property var controller
    required property var screen
    required property string screenName

    readonly property var workspaces: strip.controller.workspacesForScreen(strip.screenName)
    readonly property var currentWorkspace: strip.controller.workspaceForScreen(strip.screenName)
    readonly property real screenWidth: strip.screen && strip.screen.width > 0 ? strip.screen.width : 1920
    readonly property real screenHeight: strip.screen && strip.screen.height > 0 ? strip.screen.height : 1080
    readonly property real screenRatio: strip.screenWidth / strip.screenHeight
    readonly property real gap: Style.spacing.xl
    readonly property real labelHeight: Style.space(24)
    // Sized off the screen height, then shrunk only when a row of them would
    // not fit across.
    readonly property real wantedHeight: strip.screenHeight * strip.controller.workspaceThumbnailFraction
    readonly property real fitWidth: strip.workspaces.length > 0
        ? (strip.width - strip.gap * (strip.workspaces.length + 1)) / strip.workspaces.length
        : strip.wantedHeight * strip.screenRatio
    readonly property real thumbnailWidth: Math.max(1, Math.min(strip.wantedHeight * strip.screenRatio, strip.fitWidth))
    readonly property real thumbnailHeight: strip.thumbnailWidth / strip.screenRatio

    implicitHeight: strip.thumbnailHeight + strip.labelHeight + Style.spacing.sm

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: strip.gap

        Repeater {
            model: strip.workspaces

            delegate: Item {
                id: tile

                required property var modelData
                readonly property bool current: strip.controller.workspaceScope === "current"
                    && strip.controller.isSameWorkspace(tile.modelData, strip.currentWorkspace)
                readonly property bool focusedHere: strip.controller.isSameWorkspace(tile.modelData, strip.currentWorkspace)
                property bool hovered: false
                readonly property bool dropHovered: {
                    if (!strip.controller.dragActive)
                        return false;
                    var point = tile.mapFromItem(null, strip.controller.dragPoint.x, strip.controller.dragPoint.y);
                    return point.x >= 0 && point.y >= 0 && point.x <= tile.width && point.y <= tile.height;
                }
                onDropHoveredChanged: {
                    if (tile.dropHovered)
                        strip.controller.dropWorkspace = tile.modelData;
                    else if (strip.controller.dropWorkspace === tile.modelData)
                        strip.controller.dropWorkspace = null;
                }
                readonly property var windows: strip.controller.toplevelsOnWorkspace(strip.screenName, tile.modelData)

                width: strip.thumbnailWidth
                height: strip.thumbnailHeight + strip.labelHeight + Style.spacing.sm

                Item {
                    id: thumbnail

                    z: 1
                    width: strip.thumbnailWidth
                    height: strip.thumbnailHeight

                    Item {
                        id: thumbnailContent

                        anchors.fill: parent
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            color: Color.background
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
                            sourceSize.width: strip.thumbnailWidth
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        Repeater {
                            model: tile.windows

                            delegate: Item {
                                id: miniature

                                required property var modelData
                                readonly property var ipc: WindowModel.ipcFor(modelData)
                                readonly property var at: ipc.at || [0, 0]
                                readonly property var size: ipc.size || [0, 0]
                                readonly property real unit: strip.thumbnailWidth / strip.screenWidth

                                x: (Number(at[0]) - (strip.screen ? strip.screen.x : 0)) * unit
                                y: (Number(at[1]) - (strip.screen ? strip.screen.y : 0)) * unit
                                width: Math.max(1, Number(size[0]) * unit)
                                height: Math.max(1, Number(size[1]) * unit)
                                z: ipc.floating ? 1 : 0
                                opacity: strip.controller.dragTop === miniature.modelData ? 0.35 : 1

                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: WindowModel.waylandFor(miniature.modelData)
                                    live: strip.controller.opened
                                    paintCursor: false
                                }

                                MouseArea {
                                    property point pressPoint: Qt.point(0, 0)
                                    property bool dragging: false

                                    anchors.fill: parent
                                    enabled: !strip.controller.settingsOpen
                                    onPressed: function(mouse) {
                                        pressPoint = Qt.point(mouse.x, mouse.y);
                                        dragging = false;
                                    }
                                    onPositionChanged: function(mouse) {
                                        var point = mapToItem(null, mouse.x, mouse.y);
                                        if (!dragging && Math.abs(mouse.x - pressPoint.x) + Math.abs(mouse.y - pressPoint.y) > Style.space(6)) {
                                            dragging = true;
                                            strip.controller.beginWindowDrag(miniature.modelData, miniature, point);
                                        } else if (dragging) {
                                            strip.controller.updateWindowDrag(point);
                                        }
                                    }
                                    onReleased: {
                                        if (dragging)
                                            strip.controller.endWindowDrag();
                                    }
                                    onCanceled: {
                                        if (dragging)
                                            strip.controller.endWindowDrag();
                                        dragging = false;
                                    }
                                    onClicked: {
                                        if (dragging)
                                            dragging = false;
                                        else
                                            strip.controller.goToWorkspace(tile.modelData);
                                    }
                                }
                            }
                        }

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: thumbnailMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                    }

                    Rectangle {
                        id: thumbnailMask

                        anchors.fill: parent
                        radius: Style.cornerRadius
                        color: "black"
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Style.cornerRadius
                        color: "transparent"
                        border.color: tile.dropHovered ? Color.menu.selectedText : (tile.current ? Color.accent : (tile.hovered ? Color.menu.selectedText : Color.menu.border))
                        border.width: tile.hovered || tile.dropHovered
                            ? Math.max(4, Style.hoverBorderWidth * 2)
                            : (tile.current ? Math.max(2, Style.selectedBorderWidth) : Math.max(1, Style.normalBorderWidth))
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: thumbnail.bottom
                    anchors.topMargin: Style.spacing.sm
                    height: strip.labelHeight
                    verticalAlignment: Text.AlignVCenter
                    text: "Workspace " + String(tile.modelData.name || tile.modelData.id)
                    textFormat: Text.PlainText
                    color: tile.focusedHere ? Color.accent : Color.menu.text
                    opacity: tile.focusedHere || tile.hovered ? 1 : 0.7
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: tile.focusedHere
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !strip.controller.settingsOpen
                    cursorShape: Qt.PointingHandCursor
                    onEntered: tile.hovered = true
                    onExited: tile.hovered = false
                    onClicked: strip.controller.goToWorkspace(tile.modelData)
                }
            }
        }
    }
}
