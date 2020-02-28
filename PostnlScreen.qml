import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;

Screen {
	id: postnlScreen
	screenTitle: "Recente PostNL pakketten"

	property string actualModelText : "Pakketpost:"

	function formatDeliveryDate(dateString) {
		return dateString.substring(0, 10) + " " + dateString.substring(11,16);
	}

	function formatDelivery(status, deliveryDate) {
		if (status == 'Delivered') {
			return "Afgeleverd op " + deliveryDate;
		} else {
			if (status == 'ReturnToSender') {
				return " ";
			} else {
				return "Onderweg, aflevering vanaf " + deliveryDate;
			}
		}
	}


	onShown: {

			// add settingsscreen button
		addCustomTopRightButton("Instellingen");

		refreshScreen();
	}

	onCustomButtonClicked: {
		if (app.postnlConfigurationScreen) app.postnlConfigurationScreen.show();
	}

	function refreshScreen() {
		refreshPostnlModel();
	}


	function refreshPostnlModel() {

		postnlModel.clear();

		var shipmentDate = "";
		var shipmentSender = "";
		var shipmentTitle = "";

			// get incoming shipments

		for (var i = 0; i < app.postNLData['receiver'].length; i++) {

				// determine date
			if (app.postNLData['receiver'][i]['delivery']['status'] == 'Delivered') {
				shipmentDate = 	formatDeliveryDate(app.postNLData['receiver'][i]['delivery']['deliveryDate']);
				shipmentTitle = "Ontvangen van ";
			} else {
				if (app.postNLData['receiver'][i]['delivery']['timeframe']['from']) {
					shipmentDate = 	formatDeliveryDate(app.postNLData['receiver'][i]['delivery']['timeframe']['from']);
				} else {
					shipmentDate = "";
				}
				if (app.postNLData['receiver'][i]['delivery']['status'] == 'ReturnToSender') {
					shipmentTitle = "Retour afzender ";
				} else {
					shipmentTitle = "Te ontvangen van ";
				}
			}

				// determine sender
			if (app.postNLData['receiver'][i]['sender']) {
				if (app.postNLData['receiver'][i]['sender']['companyName']) {
					shipmentSender = app.postNLData['receiver'][i]['sender']['companyName'] + "  (" + app.postNLData['receiver'][i]['sender']['town'] + ")";
				} else {
					shipmentSender = app.postNLData['receiver'][i]['sender']['lastName'] + " (" + app.postNLData['receiver'][i]['sender']['town'] + ")";
				}
			} else {
				shipmentSender = "onbekende afzender";
			}

			postnlModel.append({deliveryDate: shipmentDate, deliveryInfo: formatDelivery(app.postNLData['receiver'][i]['delivery']['status'], shipmentDate), barcode: app.postNLData['receiver'][i]['barcode'], senderInfo: shipmentTitle + shipmentSender});
		}

			// add outgoing shipments

		for (var j = 0; j < app.postNLData['sender'].length; j++) {

			if (app.postNLData['sender'][j]['delivery']['deliveryDate']) {
				shipmentDate = 	formatDeliveryDate(app.postNLData['sender'][j]['delivery']['deliveryDate']);
			} else {
				if (app.postNLData['sender'][j]['delivery']['timeframe']['from']) {
					shipmentDate = 	formatDeliveryDate(app.postNLData['sender'][j]['delivery']['timeframe']['from']);
				} else {
					shipmentDate = "";
				}
			}
			postnlModel.append({deliveryDate: shipmentDate, deliveryInfo: formatDelivery(app.postNLData['sender'][j]['delivery']['status'], shipmentDate), barcode: app.postNLData['sender'][j]['barcode'], senderInfo: "Verstuurd naar " + app.postNLData['sender'][j]['originalReceiver']['street'] + " " + app.postNLData['sender'][j]['originalReceiver']['houseNumber'] + ", " + app.postNLData['sender'][j]['originalReceiver']['town']});
		}

			// sort on deliverydate
		sortPostnlModel();
	}

	function sortPostnlModel() {
		var n;
		var i;
		for (n=0; n < postnlModel.count; n++) {
			for (i=n+1; i < postnlModel.count; i++) {
				if (postnlModel.get(n).deliveryDate < postnlModel.get(i).deliveryDate) {
					postnlModel.move(n, i, 1);
					n=0;
				}
			}
		}
	}

	Item {
		id: header
		height: isNxt ? 55 : 45
		width: parent.width

		Text {
			id: headerText
			text: actualModelText
			font.family: qfont.semiBold.name
			font.pixelSize: isNxt ? 25 : 20
			anchors {
				left: parent.left
				leftMargin: isNxt ? 25 : 20
				bottom: parent.bottom
			}
		}


		IconButton {
			id: refreshButton
			anchors.right: parent.right
			anchors.rightMargin: isNxt ? 50 : 40
			anchors.bottom: parent.bottom
			leftClickMargin: 3
			bottomClickMargin: 5
			iconSource: "qrc:/tsc/refresh.svg"
			onClicked: app.refreshPostNLToken()
		}
	}

	GridView {
		id: postnlGridView

		model: postnlModel
		delegate: Rectangle
			{
				width: isNxt ? 975 : 760
				height: isNxt ? 60 : 48

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

		flow: GridView.TopToBottom
		cellWidth: isNxt ? 975 : 750
		cellHeight: isNxt ? 65 : 52

		anchors {
			top: header.bottom
			bottom: parent.bottom
			left: parent.left
			topMargin: 5
			leftMargin: isNxt ? 25 : 20
		}
	}

	ListModel {
		id: postnlModel
	}


	GridView {
		id: letterGridView

		model: letterModel
		delegate: Rectangle
			{
				width: isNxt ? 250 : 200
				height: isNxt ? 30 : 24


				Text {
					id: txtDelivery
					text: deliveryDate
					font.pixelSize: isNxt ? 20 : 16
					font.family: qfont.regular.name
					color: colors.clockTileColor
					anchors {
						top: parent.top
						left: parent.left
						leftMargin: 5
					}
				}
			}

		flow: GridView.TopToBottom
		cellWidth: isNxt ? 250 : 200
		cellHeight: isNxt ? 35 : 28
		visible: false

		anchors {
			top: header.bottom
			bottom: parent.bottom
			left: parent.left
			topMargin: 5
			leftMargin: isNxt ? 25 : 20
		}
	}

	ListModel {
		id: letterModel
	}
}
