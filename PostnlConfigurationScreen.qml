import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;

Screen {
	id: postnlConfigurationScreen
	screenTitle: "Instellingen PostNL app"

	onShown: {
		enableSystrayToggle.isSwitchedOn = app.enableSystray;
		postnlUseridLabel.inputText = app.postnlUserid;
		postnlUpdateFrequencyInMinutesLabel.inputText = app.postnlUpdateFrequencyInMinutes;
		postnlShowHistoryInMonthsLabel.inputText = app.postnlShowHistoryInMonths;
		postnlPassword.inputText = "**********";
		addCustomTopRightButton("Opslaan");
	}

	onCustomButtonClicked: {
		app.saveSettings();
		hide();
	}


	function validatePostnlUpdateFrequencyInMinutes(text, isFinalString) {

		if (isFinalString) {
			if (parseInt(text) < 20) return {title: "Te kort interval", content: "Minimum update interval is 20 minuten"};
		}
		if (isFinalString) {
			if (parseInt(text) > 1440) return {title: "Te lang interval", content: "Maximum update interval is 1440 minuten (1 dag)"};
		}
		return null;
	}

	function savePostnlUpdateFrequencyInMinutes(text) {

		if (text) {
			app.postnlUpdateFrequencyInMinutes = text;
			postnlUpdateFrequencyInMinutesLabel.inputText = text;
		}
	}

	function validatePostnlShowHistoryInMonths(text, isFinalString) {

		if (isFinalString) {
			if (parseInt(text) < 1) return {title: "Te kleine waarde", content: "Minimum aantal maanden is 1"};
		}
		return null;
	}

	function savePostnlShowHistoryInMonths(text) {

		if (text) {
			app.postnlShowHistoryInMonths = text;
			postnlShowHistoryInMonthsLabel.inputText = text;
			app.postnlScreen.refreshScreen(); 
		}
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
		width: isNxt ? 625 : 500
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 300 : 240
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
		leftTextAvailableWidth: isNxt ? 300 : 240
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

	EditTextLabel4421 {
		id: postnlUpdateFrequencyInMinutesLabel
		width: postnlUseridLabel.width
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 300 : 240
		leftText: "Verversinterval in min:"
		x: isNxt ? 38 : 30
		y: 10

		anchors {
			left: isNxt ? 20 : 16
			top: postnlPassword.bottom
			topMargin: 6
		}

		onClicked: {
			qnumKeyboard.open("Om de hoeveel minuten moet de inbox worden opgehaald?", postnlUpdateFrequencyInMinutesLabel.inputText, app.postnlUpdateFrequencyInMinutes, 1 , savePostnlUpdateFrequencyInMinutes, validatePostnlUpdateFrequencyInMinutes);
			qnumKeyboard.maxTextLength = 3;
			qnumKeyboard.state = "num_integer_clear_backspace";
		}
	}

	IconButton {
		id: postnlUpdateFrequencyInMinutesButton;
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: postnlUpdateFrequencyInMinutesLabel.right
			leftMargin: 6
			top: postnlUpdateFrequencyInMinutesLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Om de hoeveel minuten moet de inbox worden opgehaald?", postnlUpdateFrequencyInMinutesLabel.inputText, app.postnlUpdateFrequencyInMinutes, 1 , savePostnlUpdateFrequencyInMinutes, validatePostnlUpdateFrequencyInMinutes);
			qnumKeyboard.maxTextLength = 3;
			qnumKeyboard.state = "num_integer_clear_backspace";
		}
	}

	EditTextLabel4421 {
		id: postnlShowHistoryInMonthsLabel
		width: postnlUseridLabel.width
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 300 : 240
		leftText: "Toon maanden historie:"
		x: isNxt ? 38 : 30
		y: 10

		anchors {
			left: isNxt ? 20 : 16
			top: postnlUpdateFrequencyInMinutesLabel.bottom
			topMargin: 6
		}

		onClicked: {
			qnumKeyboard.open("Hoeveel maanden historie moet er getoond worden?", postnlShowHistoryInMonthsLabel.inputText, app.postnlShowHistoryInMonths, 1 , savePostnlShowHistoryInMonths, validatePostnlShowHistoryInMonths);
			qnumKeyboard.maxTextLength = 2;
			qnumKeyboard.state = "num_integer_clear_backspace";
		}
	}

	IconButton {
		id: postnlShowHistoryInMonthsButton;
		width: isNxt ? 50 : 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: postnlUpdateFrequencyInMinutesLabel.right
			leftMargin: 6
			top: postnlShowHistoryInMonthsLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Hoeveel maanden historie moet er getoond worden?", postnlShowHistoryInMonthsLabel.inputText, app.postnlShowHistoryInMonths, 1 , savePostnlShowHistoryInMonths, validatePostnlShowHistoryInMonths);
			qnumKeyboard.maxTextLength = 2;
			qnumKeyboard.state = "num_integer_clear_backspace";
		}
	}
}
