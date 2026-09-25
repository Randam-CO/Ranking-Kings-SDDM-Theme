import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 1920
    height: 1080

    // ----------------------------------------------------
    // COLOR PALETTE
    // ----------------------------------------------------
    QtObject {
        id: palette

        readonly property color panelBg: (typeof config !== "undefined" && config.panelBg) || "#663f3f3f"
        readonly property color textPrimary: (typeof config !== "undefined" && config.textPrimary) || "#f8f7c4"
        readonly property color textSecondary: (typeof config !== "undefined" && config.textSecondary) || "#f6e4c5"
        readonly property color textMuted: (typeof config !== "undefined" && config.textMuted) || "#b3f8f7c4"
        readonly property color inputBg: (typeof config !== "undefined" && config.inputBg) || "#3a3a32"
        readonly property color keyBg: (typeof config !== "undefined" && config.keyBg) || "#1d1d1d"
        readonly property color submitBg: (typeof config !== "undefined" && config.submitBg) || "#282924"
        readonly property color divider: (typeof config !== "undefined" && config.dividerColor) || "#33ffffff"

        readonly property color modalBg: "#e6323232"
        readonly property color modalCardBg: "#2e2e2e"
    }

    // ----------------------------------------------------
    // 4 LAYOUT MODES: Right, Left, Center, Full
    // ----------------------------------------------------
    readonly property var layoutModes: ["Right", "Left", "Center", "Full"]
    property int layoutIndex: 0
    property string panelPosition: layoutModes[layoutIndex]

    function cycleLayout(step) {
        layoutIndex = (layoutIndex + step + layoutModes.length) % layoutModes.length
        panelPosition = layoutModes[layoutIndex]
    }

    // ----------------------------------------------------
    // SESSION HELPER (Fixes /usr/share/xsessions bug)
    // ----------------------------------------------------
    property int currentSessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
    ? sessionModel.lastIndex
    : 0

    function getSessionName(idx) {
        if (typeof sessionModel !== "undefined" && sessionModel && sessionModel.count > 0) {
            var sIndex = sessionModel.index(idx, 0);

            // In SDDM, role 260 (Qt.UserRole + 4) returns the clean desktop display name
            var name = sessionModel.data(sIndex, 260);
            if (name && name.toString().length > 0 && name.indexOf("/") === -1) {
                return name.toString();
            }

            // Fallback role 258
            name = sessionModel.data(sIndex, 258);
            if (name && name.toString().length > 0 && name.indexOf("/") === -1) {
                return name.toString();
            }

            // Fallback: If it returns a file path like /usr/share/xsessions/openbox.desktop, extract "Openbox"
            var file = sessionModel.data(sIndex, 257) || sessionModel.data(sIndex, 256);
            if (file) {
                var clean = file.toString().replace(/.*\//, '').replace('.desktop', '');
                if (clean.length > 0) {
                    return clean.charAt(0).toUpperCase() + clean.slice(1);
                }
            }
        }
        return "Open Box";
    }

    readonly property string currentSessionName: getSessionName(currentSessionIndex)

    // ----------------------------------------------------
    // USER STATE & SWITCHER
    // ----------------------------------------------------
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int userCount: (typeof userModel !== "undefined" && userModel.count > 0) ? userModel.count : 1

    readonly property string selectedUser: {
        if (typeof userModel !== "undefined" && userModel && userModel.count > 0) {
            var name = userModel.data(userModel.index(userIndex, 0), Qt.UserRole + 1);
            if (name && name !== "") return name;
            if (userModel.lastUser && userModel.lastUser !== "") return userModel.lastUser;
        }
        return "randam";
    }

    property var currentTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    property bool showPasswordText: false

    function doLogin() {
        errorMessage.visible = false;

        var username = root.selectedUser;
        var password = passwordInput.text;

        // Use active session index (defaults to last successfully used session)
        var sess = (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
        ? sessionModel.lastIndex
        : root.currentSessionIndex;

        if (typeof sddm !== "undefined") {
            // Hand credentials over to Linux PAM daemon
            sddm.login(username, password, sess);
        }
    }
    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null

        function onLoginFailed() {
            errorMessage.text = "WRONG  PASSWORD!";
            errorMessage.visible = true;
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }

        function onLoginSucceeded() {
            errorMessage.visible = false;
        }

        function onInformationMessage(message) {
            errorMessage.text = message.toUpperCase();
            errorMessage.visible = true;
        }
    }

    FontLoader {
        id: mainFont
        source: "assets/fonts/main.ttf"
    }

    FontLoader {
        id: monoFont
        source: "assets/fonts/second.ttf"
    }

    // 1. Wallpaper
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "assets/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        clip: true
        smooth: true
        asynchronous: true
    }

    // 2. PANEL CONTAINER (Animated 4-Mode Layout)
    Rectangle {
        id: panelContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: palette.panelBg

        // Standard dock width (~35%)
        readonly property real standardWidth: Math.max(root.width * 0.35, 420)

        // Dynamic width calculation
        width: (root.panelPosition === "Full") ? root.width : standardWidth

        // Dynamic X positioning without anchor conflicts
        x: {
            if (root.panelPosition === "Left") return 0;
            if (root.panelPosition === "Right") return root.width - width;
            if (root.panelPosition === "Center") return (root.width - width) / 2;
            if (root.panelPosition === "Full") return 0;
            return root.width - width;
        }

        // Smooth sliding animations when switching layouts!
        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.InOutQuad }
        }
        Behavior on width {
            NumberAnimation { duration: 280; easing.type: Easing.InOutQuad }
        }

        // TOP BAR
        Item {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 20
            anchors.leftMargin: 36
            anchors.rightMargin: 28
            height: 40

            Text {
                id: langText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                readonly property int layoutCount: (typeof keyboard !== "undefined" && keyboard && keyboard.layouts)
                ? (keyboard.layouts.length || keyboard.layouts.count || 0)
                : 0

                text: {
                    if (layoutCount > 0 && keyboard.currentLayout >= 0 && keyboard.currentLayout < layoutCount) {
                        var l = keyboard.layouts[keyboard.currentLayout];
                        if (l && l.shortName) return l.shortName.toUpperCase();
                    }
                    return "ES";
                }

                color: palette.textPrimary
                font.family: mainFont.name
                font.pixelSize: 22
                font.weight: Font.DemiBold

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: langText.opacity = 0.7
                    onExited: langText.opacity = 1.0

                    onClicked: {
                        if (langText.layoutCount > 1) {
                            keyboard.currentLayout = (keyboard.currentLayout + 1) % langText.layoutCount;
                        }
                    }
                }
            }

            Image {
                id: settingsBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                source: "assets/icons/settings.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: settingsBtn.opacity = 0.7
                    onExited: settingsBtn.opacity = 1.0
                    onClicked: settingsModal.visible = !settingsModal.visible
                }
            }
        }

        // CLOCK & DATE CONTAINER
        Column {
            id: clockContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: topBar.bottom
            anchors.topMargin: 36
            spacing: -25

            Text {
                id: timeLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.currentTime, "h:mm AP")
                color: palette.textPrimary
                font.family: mainFont.name
                font.pixelSize: 64
                font.weight: Font.Normal
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.currentTime, "dddd, MMMM d")
                color: palette.textSecondary
                font.family: mainFont.name
                font.pixelSize: 24
                font.weight: Font.Light
            }
        }

        // USER SECTION
        Item {
            id: userSection
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockContainer.bottom
            anchors.topMargin: 8

            // Keeps arrows near the avatar even in Full screen mode
            width: (root.panelPosition === "Full") ? 420 : (parent.width * 0.80)
            height: 200

            Image {
                id: prevUserBtn
                anchors.left: parent.left
                anchors.leftMargin: (root.panelPosition === "Full") ? 40 : 80
                anchors.verticalCenter: avatarContainer.verticalCenter
                width: 22
                height: 38
                source: "assets/icons/arrow-left-big.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: prevUserBtn.opacity = 0.7
                    onExited: prevUserBtn.opacity = 1.0
                    onClicked: {
                        if (root.userCount > 1) {
                            root.userIndex = (root.userIndex - 1 + root.userCount) % root.userCount;
                        }
                    }
                }
            }

            Item {
                id: avatarContainer
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 168
                height: 168

                Image {
                    id: figmaAvatar
                    anchors.fill: parent
                    source: "assets/icons/profile.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: systemAvatar.status !== Image.Ready
                }

                Image {
                    id: systemAvatar
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: status === Image.Ready
                    source: {
                        if (typeof userModel !== "undefined" && userModel && userModel.count > 0) {
                            var p = userModel.data(userModel.index(root.userIndex, 0), Qt.UserRole + 3);
                            return (p && p.toString().length > 0) ? p : "";
                        }
                        return "";
                    }
                }
            }

            Image {
                id: nextUserBtn
                anchors.right: parent.right
                anchors.rightMargin: (root.panelPosition === "Full") ? 40 : 80
                anchors.verticalCenter: avatarContainer.verticalCenter
                width: 22
                height: 38
                source: "assets/icons/arrow-right-big.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: nextUserBtn.opacity = 0.7
                    onExited: nextUserBtn.opacity = 1.0
                    onClicked: {
                        if (root.userCount > 1) {
                            root.userIndex = (root.userIndex + 1) % root.userCount;
                        }
                    }
                }
            }

            Text {
                id: userNameLabel
                anchors.top: avatarContainer.bottom
                anchors.topMargin: -16
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.selectedUser
                color: palette.textPrimary
                font.family: mainFont.name
                font.pixelSize: 28
                font.weight: Font.Normal
            }
        }

        // PASSWORD BOX
        Rectangle {
            id: passwordBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: userSection.bottom
            anchors.topMargin: 40

            // Constrains nicely in Full mode instead of stretching into an awkward bar
            width: (root.panelPosition === "Full")
            ? Math.min(parent.width * 0.45, 520)
            : (parent.width - 68)
            height: 46
            color: palette.inputBg
            radius: 2
            clip: true

            Rectangle {
                id: keySection
                width: 48
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: palette.keyBg

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: "assets/icons/key.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: palette.divider
                }
            }

            Rectangle {
                id: submitBtn
                width: 50
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                color: palette.submitBg

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: "assets/icons/submit.svg"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: submitBtn.opacity = 0.8
                    onExited: submitBtn.opacity = 1.0
                    onClicked: root.doLogin()
                }
            }

            Image {
                id: eyeBtn
                anchors.right: submitBtn.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                source: "assets/icons/eye.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: root.showPasswordText ? 1.0 : 0.6

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showPasswordText = !root.showPasswordText
                }
            }

            TextInput {
                id: passwordInput
                anchors.left: keySection.right
                anchors.right: eyeBtn.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 8

                verticalAlignment: TextInput.AlignVCenter
                color: palette.textPrimary
                font.family: monoFont.name
                font.pixelSize: 18

                echoMode: root.showPasswordText ? TextInput.Normal : TextInput.Password
                focus: false
                onAccepted: root.doLogin()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    text: "Password"
                    color: palette.textMuted
                    font.family: mainFont.name
                    font.pixelSize: 18
                    visible: passwordInput.text.length === 0
                }
            }
        }

        // ERROR MESSAGE
        Text {
            id: errorMessage
            visible: false
            anchors.top: passwordBox.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WRONG  PASSWORD!"
            color: palette.textPrimary
            font.family: monoFont.name
            font.pixelSize: 22
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }
    }

    // ====================================================
    // 3. SETTINGS MODAL WINDOW OVERLAY
    // ====================================================
    Item {
        id: settingsModal
        anchors.fill: parent
        visible: false
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: {
                sessionDropdownList.visible = false
                settingsModal.visible = false
            }
        }

        Rectangle {
            id: modalCard
            anchors.centerIn: parent
            width: Math.min(812, parent.width * 0.85)
            height: Math.min(468, parent.height * 0.85)
            color: palette.modalBg
            radius: 20
            clip: false

            MouseArea {
                anchors.fill: parent
                onClicked: sessionDropdownList.visible = false
            }

            // ROW 1: SESSION DROPDOWN
            Item {
                id: sessionRow
                anchors.top: parent.top
                anchors.topMargin: 45
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 45
                anchors.rightMargin: 45
                height: 60

                Text {
                    id: sessionLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Session :"
                    color: palette.textPrimary
                    font.family: mainFont.name
                    font.pixelSize: 32
                }

                Rectangle {
                    id: sessionBox
                    anchors.left: sessionLabel.right
                    anchors.leftMargin: 25
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 52
                    color: palette.keyBg
                    radius: 6

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentSessionName
                        color: palette.textPrimary
                        font.family: mainFont.name
                        font.pixelSize: 24
                    }

                    // Vector Drop Icon (assets/icons/drop.svg)
                    Image {
                        id: dropIcon
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: "assets/icons/drop.svg"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sessionDropdownList.visible = !sessionDropdownList.visible
                    }
                }
            }

            // ROW 2: 4-WAY LAYOUT SELECTOR (< Left / Right / Center / Full >)
            Row {
                id: layoutRow
                anchors.top: sessionRow.bottom
                anchors.topMargin: 30
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Layout :"
                    color: palette.textPrimary
                    font.family: mainFont.name
                    font.pixelSize: 32
                }

                // Left Arrow (<)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "<"
                    color: palette.textPrimary
                    font.family: monoFont.name
                    font.pixelSize: 28
                    font.weight: Font.Bold

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.7
                        onExited: parent.opacity = 1.0
                        onClicked: root.cycleLayout(-1)
                    }
                }

                // Layout Name
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.panelPosition
                    color: palette.textPrimary
                    font.family: mainFont.name
                    font.pixelSize: 32
                }

                // Right Arrow (>)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    color: palette.textPrimary
                    font.family: monoFont.name
                    font.pixelSize: 28
                    font.weight: Font.Bold

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.7
                        onExited: parent.opacity = 1.0
                        onClicked: root.cycleLayout(1)
                    }
                }
            }

            // ROW 3: POWER ACTIONS
            Row {
                id: powerRow
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 35

                // 1. Shutdown
                Rectangle {
                    width: 215
                    height: 185
                    color: palette.modalCardBg
                    radius: 8

                    Column {
                        anchors.centerIn: parent
                        spacing: 18

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52
                            height: 52
                            source: "assets/icons/shutdown.svg"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Shutdown"
                            color: palette.textPrimary
                            font.family: mainFont.name
                            font.pixelSize: 26
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.75
                        onExited: parent.opacity = 1.0
                        onClicked: {
                            if (typeof sddm !== "undefined") sddm.powerOff();
                        }
                    }
                }

                // 2. Restart
                Rectangle {
                    width: 215
                    height: 185
                    color: palette.modalCardBg
                    radius: 8

                    Column {
                        anchors.centerIn: parent
                        spacing: 18

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52
                            height: 52
                            source: "assets/icons/restart.svg"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Restart"
                            color: palette.textPrimary
                            font.family: mainFont.name
                            font.pixelSize: 26
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.75
                        onExited: parent.opacity = 1.0
                        onClicked: {
                            if (typeof sddm !== "undefined") sddm.reboot();
                        }
                    }
                }

                // 3. Sleep
                Rectangle {
                    width: 215
                    height: 185
                    color: palette.modalCardBg
                    radius: 8

                    Column {
                        anchors.centerIn: parent
                        spacing: 18

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52
                            height: 52
                            source: "assets/icons/sleep.svg"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Sleep"
                            color: palette.textPrimary
                            font.family: mainFont.name
                            font.pixelSize: 26
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.75
                        onExited: parent.opacity = 1.0
                        onClicked: {
                            if (typeof sddm !== "undefined") sddm.suspend();
                        }
                    }
                }
            }

            // DROPDOWN MENU LIST
            Rectangle {
                id: sessionDropdownList
                visible: false
                z: 200
                anchors.top: sessionRow.bottom
                anchors.left: sessionRow.left
                anchors.leftMargin: 155
                anchors.right: sessionRow.right
                height: Math.min((sessionListView.count || 1) * 44 + 10, 180)
                color: palette.keyBg
                radius: 6
                border.color: palette.divider
                border.width: 1
                clip: true

                ListView {
                    id: sessionListView
                    anchors.fill: parent
                    anchors.margins: 4
                    model: (typeof sessionModel !== "undefined" && sessionModel.count > 0)
                    ? sessionModel
                    : ["Open Box", "LXQt", "Plasma (Wayland)", "Plasma (X11)"]

                    delegate: Rectangle {
                        width: sessionListView.width
                        height: 38
                        color: itemMouse.containsMouse ? "#33ffffff" : "transparent"
                        radius: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                            text: (typeof modelData === "string")
                            ? modelData
                            : root.getSessionName(index)
                            color: palette.textPrimary
                            font.family: mainFont.name
                            font.pixelSize: 20
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentSessionIndex = index
                                if (typeof sessionModel !== "undefined") {
                                    sessionModel.lastIndex = index
                                }
                                sessionDropdownList.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
