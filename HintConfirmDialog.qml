import QtQuick
import qs.Commons
import qs.Ui

// Confirm dialog with hotkey hints stacked under button labels
// (avoids wide single-line buttons overflowing the card).
Item {
  id: root

  property bool opened: false
  property string message: ""
  property string cancelText: "Cancel"
  property string confirmText: "Confirm"
  property string cancelHint: "Esc"
  property string confirmHint: "Ctrl+Enter"
  property int selectedIndex: 1
  property color background: Color.background
  property color foreground: Color.foreground
  property color scrim: Util.alpha(Color.background, 0.7)
  property color selectedBackground: Util.alpha(Color.foreground, 0.08)
  property color selectedText: Color.accent
  property string fontFamily: Style.font.family
  property int cornerRadius: Style.cornerRadius

  signal canceled()
  signal confirmed()

  function handleKey(event) {
    if (!root.opened) return false
    if (event.key === Qt.Key_Escape) {
      root.canceled()
      return true
    }
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
        || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      root.selectedIndex = root.selectedIndex === 0 ? 1 : 0
      return true
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.selectedIndex === 0) root.canceled()
      else root.confirmed()
      return true
    }
    return false
  }

  visible: opened
  z: 20

  Rectangle {
    anchors.fill: parent
    color: root.scrim

    MouseArea { anchors.fill: parent; onClicked: root.canceled() }

    BorderSurface {
      id: card
      width: Math.min(parent.width - Style.space(32), Style.space(370))
      height: card.contentTopInset + card.contentBottomInset
        + messageText.implicitHeight + Style.space(20)
        + Math.max(Style.space(44), Style.space(44))
      anchors.centerIn: parent
      color: root.background
      borderSpec: Border.flat(root.selectedText, Style.normalBorderWidth)
      padding: Style.space(18)
      radius: root.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Text {
          id: messageText
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          text: root.message
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          wrapMode: Text.WordWrap
        }

        Row {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Style.space(10)

          Repeater {
            model: [
              { label: root.cancelText, hint: root.cancelHint, action: "cancel" },
              { label: root.confirmText, hint: root.confirmHint, action: "confirm" }
            ]

            BorderSurface {
              required property int index
              required property var modelData

              readonly property bool selected: root.selectedIndex === index
              readonly property bool destructive: index === 1

              width: Math.max(Style.space(88), btnCol.implicitWidth + Style.space(20))
              height: Math.max(Style.space(44), btnCol.implicitHeight + Style.space(10))
              color: selected
                ? (destructive ? Util.alpha(Color.urgent, 0.22) : root.selectedBackground)
                : "transparent"
              borderSpec: Border.flat(destructive
                ? (selected ? Color.urgent : Util.alpha(Color.urgent, 0.56))
                : (selected ? root.selectedText : Util.alpha(root.foreground, 0.38)), Style.normalBorderWidth)
              radius: 0

              Column {
                id: btnCol
                anchors.centerIn: parent
                spacing: Style.space(1)

                Text {
                  textFormat: Text.PlainText
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.label
                  color: destructive
                    ? (selected ? Color.urgent : root.foreground)
                    : (selected ? root.selectedText : root.foreground)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.hint
                  color: Qt.darker(root.foreground, 1.45)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption * 0.85
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: {
                  if (index === 0) root.canceled()
                  else root.confirmed()
                }
              }
            }
          }
        }
      }
    }
  }
}
