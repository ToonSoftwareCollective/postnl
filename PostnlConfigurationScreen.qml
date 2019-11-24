import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;

Screen {
	id: postnlConfigurationScreen
	screenTitle: "Instellingen PostNL app"

	onShown: {
		enableSystrayToggle.isSwitchedOn = app.enableSystray;
		postnlUseridLabel.inputText = app.postnlUserid;
		addCustomTopRightButton("Opslaan");
	}

	onCustomButtonClicked: {
		app.postNLData = {};
		app.lettersData = {};
		app.tileBarcode = 'Geen Pakketten gevonden';
		app.tileSender = '';
		app.saveSettings();
		app.refreshPostNLData();
		hide();
	}


	function savePostnlUserid(text) {

		if (text) {
			app.postnlUserid = text;
			postnlUseridLabel.inputText = text;
		}
	}

	function savePostnlPassword(text) {

		if (text) {
			app.postnlPassword = text;
		}
	}

	EditTextLabel4421 {
		id: postnlUseridLabel
		width: isNxt ? 550 : 440
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 200 : 160
		leftText: "PostNL Userid:"
		x: isNxt ? 38 : 30
		y: 10

		anchors {
			left: isNxt ? 20 : 16
			top: parent.top
			topMargin: isNxt ? 30 : 24
		}

		onClicked: {
			qkeyboard.open("Voer het userid in van uw PostNL account", postnlUseridLabel.inputText, savePostnlUserid)
		}
	}

	IconButton {
		id: postnlUseridButton;
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: postnlUseridLabel.right
			leftMargin: 6
			top: postnlUseridLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qkeyboard.open("Voer het userid in van uw PostNL account", postnlUseridLabel.inputText, savePostnlUserid)
		}
	}


	EditTextLabel4421 {
		id: postnlPassword
		width: postnlUseridLabel.width
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 200 : 160
		leftText: "Password:"

		anchors {
			left: postnlUseridLabel.left
			top: postnlUseridLabel.bottom
			topMargin: 6
		}

		onClicked: {
			qkeyboard.open("Voer het wachtwoord in:", postnlPassword.inputText, savePostnlPassword)
		}
	}

	Text {
		id: enableSystrayLabel
		width: isNxt ? 200 : 160
		height: isNxt ? 45 : 36
		text: "Icon in systray"
		font.family: qfont.semiBold.name
		font.pixelSize: isNxt ? 25 : 20
		anchors {
			left: postnlUseridButton.right
			leftMargin: isNxt ? 10 : 8
			top: postnlUseridLabel.top
		}
	}

	OnOffToggle {
		id: enableSystrayToggle
		height: isNxt ? 45 : 36
		anchors.left: enableSystrayLabel.right
		anchors.leftMargin: 10
		anchors.top: enableSystrayLabel.top
		leftIsSwitchedOn: false
		onSelectedChangedByUser: {
			if (isSwitchedOn) {
				app.enableSystray = true;
			} else {
				app.enableSystray = false;
			}
		}
	}

	IconButton {
		id: postnlPasswordButton;
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: postnlPassword.right
			leftMargin: 6
			top: postnlPassword.top
		}

		topClickMargin: 3
		onClicked: {
			qkeyboard.open("Voer het wachtwoord in:", postnlPassword.inputText, savePostnlPassword)
		}
	}

}
