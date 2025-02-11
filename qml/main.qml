/**
 * SPDX-FileCopyrightText: 2018-2020 Black Hat <bhat@encom.eu.org>
 * SPDX-FileCopyrightText: 2020 Carl Schwan <carl@carlschwan.eu>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */
import QtQuick 2.14
import QtQuick.Controls 2.14 as QQC2
import QtQuick.Window 2.2
import QtQuick.Layouts 1.14

import org.kde.kirigami 2.12 as Kirigami

import org.kde.neochat 1.0
import NeoChat.Component 1.0
import NeoChat.Panel 1.0
import NeoChat.Dialog 1.0
import NeoChat.Page 1.0

Kirigami.ApplicationWindow {
    id: root

    property int columnWidth: Kirigami.Units.gridUnit * 13

    minimumWidth: Kirigami.Units.gridUnit * 15
    minimumHeight: Kirigami.Units.gridUnit * 20

    wideScreen: width > columnWidth * 5

    onClosing: Controller.saveWindowGeometry(root)

    pageStack.initialPage: LoadingPage {}

    Connections {
        target: root.quitAction
        function onTriggered() {
            Qt.quit()
        }
    }

    // This timer allows to batch update the window size change to reduce
    // the io load and also work around the fact that x/y/width/height are
    // changed when loading the page and overwrite the saved geometry from
    // the previous session.
    Timer {
        id: saveWindowGeometryTimer
        interval: 1000
        onTriggered: Controller.saveWindowGeometry(root)
    }

    onWidthChanged: saveWindowGeometryTimer.restart()
    onHeightChanged: saveWindowGeometryTimer.restart()
    onXChanged: saveWindowGeometryTimer.restart()
    onYChanged: saveWindowGeometryTimer.restart()

    /**
     * Manage opening and close rooms
     * TODO this should probably be moved to C++
     */
    QtObject {
        id: roomManager

        property var actionsHandler: ActionsHandler {
            room: roomManager.currentRoom
            connection: Controller.activeConnection
            onRoomJoined: {
                roomManager.enterRoom(Controller.activeConnection.room(roomName))
            }
        }

        property var currentRoom: null
        property alias pageStack: root.pageStack
        property var roomList: null
        property Item roomItem: null

        readonly property bool hasOpenRoom: currentRoom !== null

        signal leaveRoom(string room);
        signal openRoom(string room);

        function roomByAliasOrId(aliasOrId) {
            return Controller.activeConnection.room(aliasOrId)
        }

        function openRoomAndEvent(room, event) {
            enterRoom(room)
            roomItem.goToEvent(event)
        }

        function loadInitialRoom() {
            if (Config.openRoom) {
                const room = Controller.activeConnection.room(Config.openRoom);
                currentRoom = room;
                roomItem = pageStack.push("qrc:/imports/NeoChat/Page/RoomPage.qml", { 'currentRoom': room, });
                connectRoomToSignal(roomItem);
            } else {
                // TODO create welcome page
            }
        }

        function enterRoom(room) {
            if (currentRoom != null) {
                roomItem.currentRoom = room;
                pageStack.currentIndex = pageStack.depth - 1;
            } else {
                roomItem = pageStack.push("qrc:/imports/NeoChat/Page/RoomPage.qml", { 'currentRoom': room, });
            }
            currentRoom = room;
            Config.openRoom = room.id;
            Config.save();
            connectRoomToSignal(roomItem);
            return roomItem;
        }

        function getBack() {
            pageStack.replace("qrc:/imports/NeoChat/Page/RoomPage.qml", { 'currentRoom': currentRoom, });
        }

        function openWindow(room) {
            const secondayWindow = roomWindow.createObject(applicationWindow(), {currentRoom: room});
            secondayWindow.width = root.width - roomList.width;
            secondayWindow.show();
        }

        function connectRoomToSignal(item) {
            if (!roomList) {
                console.log("Should not happen: no room list page but room page");
            }
            item.switchRoomUp.connect(function() {
                roomList.goToNextRoom();
            });

            item.switchRoomDown.connect(function() {
                roomList.goToPreviousRoom();
            });
        }
    }

    function pushReplaceLayer(page, args) {
        if (pageStack.layers.depth === 2) {
            pageStack.layers.replace(page, args);
        } else {
            pageStack.layers.push(page, args);
        }
    }

    function showWindow() {
        root.show()
        root.raise()
        root.requestActivate()
    }

    contextDrawer: RoomDrawer {
        id: contextDrawer
        contentItem.implicitWidth: columnWidth
        edge: Qt.application.layoutDirection == Qt.RightToLeft ? Qt.LeftEdge : Qt.RightEdge
        modal: !root.wideScreen || !enabled
        onEnabledChanged: drawerOpen = enabled && !modal
        onModalChanged: drawerOpen = !modal
        enabled: roomManager.hasOpenRoom && pageStack.layers.depth < 2 && pageStack.depth < 3
        room: roomManager.currentRoom
        handleVisible: enabled && pageStack.layers.depth < 2 && pageStack.depth < 3
    }

    pageStack.columnView.columnWidth: Kirigami.Units.gridUnit * 17

    globalDrawer: Kirigami.GlobalDrawer {
        property bool hasLayer
        contentItem.implicitWidth: columnWidth
        isMenu: true
        actions: [
            Kirigami.Action {
                text: i18n("Explore rooms")
                icon.name: "compass"
                onTriggered: pushReplaceLayer("qrc:/imports/NeoChat/Page/JoinRoomPage.qml", {"connection": Controller.activeConnection})
                enabled: pageStack.layers.currentItem.title !== i18n("Explore Rooms") && Controller.accountCount > 0
            },
            Kirigami.Action {
                text: i18n("Start a Chat")
                icon.name: "irc-join-channel"
                onTriggered: pushReplaceLayer("qrc:/imports/NeoChat/Page/StartChatPage.qml", {"connection": Controller.activeConnection})
                enabled: pageStack.layers.currentItem.title !== i18n("Start a Chat") && Controller.accountCount > 0
            },
            Kirigami.Action {
                text: i18n("Create a Room")
                icon.name: "irc-join-channel"
                onTriggered: {
                    let dialog = createRoomDialog.createObject(root.overlay);
                    dialog.open();
                }
                shortcut: StandardKey.New
                enabled: pageStack.layers.currentItem.title !== i18n("Start a Chat") && Controller.accountCount > 0
            },
            Kirigami.Action {
                text: i18n("Accounts")
                icon.name: "im-user"
                onTriggered: pushReplaceLayer("qrc:/imports/NeoChat/Page/AccountsPage.qml")
                enabled: pageStack.layers.currentItem.title !== i18n("Accounts") && Controller.accountCount > 0

            },
            Kirigami.Action {
                text: i18n("Devices")
                iconName: "network-connect"
                onTriggered: pageStack.layers.push("qrc:/imports/NeoChat/Page/DevicesPage.qml")
                enabled: pageStack.layers.currentItem.title !== i18n("Devices") && Controller.accountCount > 0
            },
            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "settings-configure"
                onTriggered: pushReplaceLayer("qrc:/imports/NeoChat/Page/SettingsPage.qml")
                enabled: pageStack.layers.currentItem.title !== i18n("Settings")
                shortcut: StandardKey.Preferences
            },
            Kirigami.Action {
                text: i18n("About NeoChat")
                icon.name: "help-about"
                onTriggered: pushReplaceLayer(aboutPage)
                enabled: pageStack.layers.currentItem.title !== i18n("About")
            },
            Kirigami.Action {
                text: i18n("Logout")
                icon.name: "list-remove-user"
                enabled: Controller.accountCount > 0
                onTriggered: Controller.logout(Controller.activeConnection, true)
            },
            Kirigami.Action {
                text: i18n("Quit")
                icon.name: "gtk-quit"
                shortcut: StandardKey.Quit
                onTriggered: Qt.quit()
            }
        ]
    }

    Component {
        id: aboutPage
        Kirigami.AboutPage {
            aboutData: Controller.aboutData
        }
    }

    Component {
        id: roomListComponent
        RoomListPage {
            id: roomList
            activeConnection: Controller.activeConnection
        }
    }
    Connections {
        target: LoginHelper
        function onInitialSyncFinished() {
            roomManager.roomList = pageStack.replace(roomListComponent);
        }
    }

    Connections {
        target: Controller

        function onInitiated() {
            if (roomManager.hasOpenRoom) {
                return;
            }
            if (Controller.accountCount === 0) {
                pageStack.replace("qrc:/imports/NeoChat/Page/WelcomePage.qml", {});
            } else {
                roomManager.roomList = pageStack.replace(roomListComponent, {'activeConnection': Controller.activeConnection});
                roomManager.loadInitialRoom();
            }
        }

        function onBusyChanged() {
            if(!Controller.busy && roomManager.roomList === null) {
                roomManager.roomList = pageStack.replace(roomListComponent);
            }
        }

        function onRoomJoined(roomId) {
            const room = Controller.activeConnection.room(roomId);
            return roomManager.enterRoom(room);
        }

        function onConnectionDropped() {
            if (Controller.accountCount === 0) {
                pageStack.clear();
                pageStack.replace("qrc:/imports/NeoChat/Page/WelcomePage.qml");
            }
        }

        function onGlobalErrorOccured(error, detail) {
            showPassiveNotification(error + ": " + detail)
        }

        function onShowWindow() {
            root.showWindow()
        }

        function onOpenRoom(room) {
            roomManager.enterRoom(room)
        }

        function onUserConsentRequired(url) {
            consentSheet.url = url
            consentSheet.open()
        }
    }

    Connections {
        target: Controller.activeConnection
        onDirectChatAvailable: {
            roomManager.enterRoom(Controller.activeConnection.room(directChat.id));
        }
    }

    Kirigami.OverlaySheet {
        id: consentSheet

        property string url: ""

        header: Kirigami.Heading {
            text: i18n("User consent")
        }

        QQC2.Label {
            id: label

            text: i18n("Your homeserver requires you to agree to its terms and conditions before being able to use it. Please click the button below to read them.")
            wrapMode: Text.WordWrap
            width: parent.width
        }
        footer: QQC2.Button {
            text: i18n("Open")
            onClicked: Qt.openUrlExternally(consentSheet.url)
        }
    }

    Component {
        id: createRoomDialog

        CreateRoomDialog {}
    }

    Component {
        id: roomWindow
        RoomWindow {}
    }

    function handleLink(link, currentRoom) {
        if (link.startsWith("https://matrix.to/")) {
            var content = link.replace("https://matrix.to/#/", "").replace(/\?.*/, "")
            if(content.match("^[#!]")) {
                if(content.includes("/")) {
                    var result = content.match("([!#].*:.*)/(\\$.*)")
                    if(!result) {
                        return
                    }
                    if(result[1] == currentRoom.id) {
                        roomManager.roomItem.goToEvent(result[2])
                    } else {
                        roomManager.openRoomAndEvent(roomManager.roomByAliasOrId(result[1]), result[2])
                    }
                } else {
                    roomManager.enterRoom(roomManager.roomByAliasOrId(content))
                }
            } else if(content.match("^@")) {
                let dialog = userDialog.createObject(root.overlay, {room: currentRoom, user: currentRoom.user(content)})
                dialog.open()
                console.log(dialog.user)
            }
        } else {
            Qt.openUrlExternally(link)
        }
    }

    Component {
        id: userDialog
        UserDetailDialog {
        }
    }
}
