import QtQuick 1.1

import qb.components 1.0
import qb.base 1.0

SystrayIcon {
	id: postnlSystrayIcon
	posIndex: 9000
	property string objectName: "postnlSystray"
	visible: app.enableSystray

	onClicked: {
		if (app.postnlScreen) app.postnlScreen.show();
	}

	Image {
		id: imgNewMessage
		anchors.centerIn: parent
		source: "./drawables/postnl.png"

	}
}
