/**
 * SPDX-FileCopyrightText: 2018-2020 Black Hat <bhat@encom.eu.org>
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls.Material 2.12
import org.kde.kirigami 2.13 as Kirigami

import NeoChat.Component 1.0
import NeoChat.Dialog 1.0
import NeoChat.Setting 1.0

RowLayout {
    id: row

    Kirigami.Avatar {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        Layout.alignment: Qt.AlignTop

        name: author.name
        source: author.avatarMediaId ? ("image://mxc/" + author.avatarMediaId) : ""
        color: author.color

        Component {
            id: userDetailDialog

            UserDetailDialog {}
        }

        MouseArea {
            anchors.fill: parent
            onClicked: userDetailDialog.createObject(ApplicationWindow.overlay, {"room": currentRoom, "user": author.object, "displayName": author.displayName, "avatarMediaId": author.avatarMediaId, "avatarUrl": author.avatarUrl}).open()
        }
    }

    Label {
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        textFormat: Text.RichText
        text: "<style>a {text-decoration: none;}</style><a href=\"https://matrix.to/#/" + author.id + "\" style='color: " + author.color + "'>" + author.displayName + "</a> " + display
        onLinkActivated: Qt.openUrlExternally(link)
    }
}
