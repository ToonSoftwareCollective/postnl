import QtQuick 2.1
//import qb.base 1.0
import qb.components 1.0

Tile {
	id: postnlTile

	onClicked: {
		if (app.loggedIn) {
			stage.openFullscreen(app.postnlScreenUrl);
		} else {
			qdialog.showDialog(qdialog.SizeSmall, "PostNL app mededeling", "Wachten op succesvolle aanmelding bij PostNL.\nDit kan enige tijd duren." , "Sluiten");
			stage.openFullscreen(app.postnlConfigurationScreenUrl);
		}
	}

	Text {
		id: txtBarcode
		text: app.tileBarcode
		color: colors.clockTileColor
		anchors {
			baseline: parent.top
			baselineOffset: isNxt ? 50 : 40
			horizontalCenter: parent.horizontalCenter
		}
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.regular.name
	}

	Text {
		id: txtSender
		text: (app.tileSender.length > 2) ? "Van: " + app.tileSender : "via PostNL"
		color: colors.clockTileColor
		anchors {
			top: txtBarcode.bottom
			horizontalCenter: parent.horizontalCenter
		}
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.bold.name
	}

	Text {
		id: txtDate
		text: (app.tileDate.length > 5) ? "Verwacht op " + app.tileDate : app.tileDate
		color: colors.clockTileColor
		anchors {
			baseline: parent.top
			baselineOffset: isNxt ? 120 : 95
			horizontalCenter: parent.horizontalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.regular.name
	}

	Text {
		id: txtTime
		text: app.tileTime
		color: colors.clockTileColor
		anchors {
			top: txtDate.bottom
			horizontalCenter: parent.horizontalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: isNxt ? 20 : 16
		font.family: qfont.regular.name
	}
}
