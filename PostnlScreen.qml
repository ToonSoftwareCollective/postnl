import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;
import FileIO 1.0

Screen {
	id: postnlScreen
	screenTitle: "Recente PostNL pakketten"

	property string actualModelText : "Pakketpost van de afgelopen maand:"
	property string lastupdate

	FileIO {
		id: postnlInboxFile
		source: "file:///tmp/postnl/POSTNL-Inbox.json"
 	}

	FileIO {
		id: lastupdateFile
		source: "file:///tmp/postnl/lastupdate.log"
 	}

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
	}

	onCustomButtonClicked: {
		if (app.postnlConfigurationScreen) app.postnlConfigurationScreen.show();
	}

	function refreshScreen() {
		refreshPostnlModel();
	}


	function refreshPostnlModel() {

		var lastupdateText = lastupdateFile.read();
		lastupdate = lastupdateText.substring(0,16) + "  ";

			// clear Tile
		app.tileDate =  "";
		app.tileTime =  "";
		app.tileBarcode = "Geen pakketten verwacht";
		app.tileSender = "";

			// read inbox

		var postNLData = JSON.parse(postnlInboxFile.read());
		if (postNLData['receiver'].length > 0) {

				//format tile when parcel is coming
			if (postNLData['receiver'][0]['delivery']['status'] !== 'Delivered') {
				if (postNLData['receiver'][0]['delivery']['timeframe']['from']) {
					app.tileDate =  postNLData['receiver'][0]['delivery']['timeframe']['from'].substring(0,10);
					app.tileTime =  postNLData['receiver'][0]['delivery']['timeframe']['from'].substring(11,16) +  " - " + postNLData['receiver'][0]['delivery']['timeframe']['to'].substring(11,16);
				} else {
					app.tileDate =  " ";
					app.tileTime =  " ";
				}
				app.tileBarcode = postNLData['receiver'][0]['barcode'];
				if (postNLData['receiver'][0]['sender']['companyName']) {
					app.tileSender = postNLData['receiver'][0]['sender']['companyName'];
				}
			}
		}

			// fill screen

		postnlModel.clear();

		var shipmentDate = "";
		var shipmentSender = "";
		var shipmentTitle = "";

			// calculate cut off date showing parcels

		var now = new Date();
		var thisMonth = now.getMonth();
    		now.setMonth(thisMonth - app.postnlShowHistoryInMonths);		// x months in the past

		var strMon = now.getMonth() + 1;
		if (strMon < 10) {
			strMon = "0" + strMon;
		}
		var strDay = now.getDate();
		if (strDay < 10) {
			strDay = "0" + strDay;
		}
		var cutoffDate = now.getFullYear() + "-" + strMon + "-" +  strDay;

			// get incoming shipments

		for (var i = 0; i < postNLData['receiver'].length; i++) {

				// determine date
			if (postNLData['receiver'][i]['delivery']['status'] == 'Delivered') {
				shipmentDate = 	formatDeliveryDate(postNLData['receiver'][i]['delivery']['deliveryDate']);
				shipmentTitle = "Ontvangen van ";
			} else {
				if (postNLData['receiver'][i]['delivery']['timeframe']['from']) {
					shipmentDate = 	formatDeliveryDate(postNLData['receiver'][i]['delivery']['timeframe']['from']);
				} else {
					shipmentDate = "";
				}
				if (postNLData['receiver'][i]['delivery']['status'] == 'ReturnToSender') {
					shipmentTitle = "Retour afzender ";
				} else {
					shipmentTitle = "Te ontvangen van ";
				}
			}

			if (cutoffDate < shipmentDate.substring(0,10)) {
					// determine sender
				if (postNLData['receiver'][i]['sender']) {
					if (postNLData['receiver'][i]['sender']['companyName']) {
						shipmentSender = postNLData['receiver'][i]['sender']['companyName'] + "  (" + postNLData['receiver'][i]['sender']['town'] + ")";
					} else {
						shipmentSender = postNLData['receiver'][i]['sender']['lastName'] + " (" + postNLData['receiver'][i]['sender']['town'] + ")";
					}
				} else {
					shipmentSender = "onbekende afzender";
				}
				postnlModel.append({deliveryDate: shipmentDate, deliveryInfo: formatDelivery(postNLData['receiver'][i]['delivery']['status'], shipmentDate), barcode: postNLData['receiver'][i]['barcode'], senderInfo: shipmentTitle + shipmentSender});
			}
		}

			// add outgoing shipments

		for (var j = 0; j < postNLData['sender'].length; j++) {

			if (postNLData['sender'][j]['delivery']['deliveryDate']) {
				shipmentDate = 	formatDeliveryDate(postNLData['sender'][j]['delivery']['deliveryDate']);
			} else {
				if (postNLData['sender'][j]['delivery']['timeframe']['from']) {
					shipmentDate = 	formatDeliveryDate(postNLData['sender'][j]['delivery']['timeframe']['from']);
				} else {
					shipmentDate = "";
				}
			}
			if (cutoffDate < shipmentDate.substring(0,10)) {
				postnlModel.append({deliveryDate: shipmentDate, deliveryInfo: formatDelivery(postNLData['sender'][j]['delivery']['status'], shipmentDate), barcode: postNLData['sender'][j]['barcode'], senderInfo: "Verstuurd naar " + postNLData['sender'][j]['originalReceiver']['street'] + " " + postNLData['sender'][j]['originalReceiver']['houseNumber'] + ", " + postNLData['sender'][j]['originalReceiver']['town']});
			}
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

		Text {
			id: updatedText
			text: "bijgewerkt op: " + lastupdate
			anchors {
				bottom: parent.bottom
				right: parent.right
			}
			font {
				pixelSize: isNxt ? 18 : 15
				family: qfont.italic.name
			}
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
