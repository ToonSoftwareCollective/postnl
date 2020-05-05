import QtQuick 2.1
import qb.components 1.0

Rectangle {
	id: postnlGridDelegate

	width: isNxt ? parent.width - 94 : parent.width - 75
	height: isNxt ? 55 : 44

	Text {
		id: txtShippedBy
		text: senderInfo
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.bold.name
		color: colors.clockTileColor
		anchors {
			top: parent.top
			left: parent.left
			leftMargin: 5
		}
	}

	Text {
		id: txtDelivery
		text: deliveryInfo
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.regular.name
		color: colors.clockTileColor
		anchors {
			top: parent.top
			right: parent.right
			rightMargin: 5
		}
	}

	Text {
		id: txtBarcode
		text: barcode
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.regular.name
		color: colors.clockTileColor
		anchors {
			top: txtShippedBy.bottom
			left: txtShippedBy.left
		}
	}
}