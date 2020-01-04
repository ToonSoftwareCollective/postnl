import QtQuick 2.1

import qb.components 1.0
import qb.base 1.0

SystrayIcon {
	id: postnlSystrayIcon
	posIndex: 9000
	property string objectName: "postnlSystray"
	visible: app.enableSystray

	onClicked: {
		if (app.loggedIn) {
			stage.openFullscreen(app.postnlScreenUrl);
		} else {
			qdialog.showDialog(qdialog.SizeSmall, "PostNL app mededeling", "Wachten op succesvolle aanmelding bij PostNL.\nDit kan enige tijd duren." , "Sluiten");
			stage.openFullscreen(app.postnlConfigurationScreenUrl);
		}
	}

	Image {
		id: imgNewMessage
		anchors.centerIn: parent
		source: "qrc:/tsc/postnl.png"

	}
}
