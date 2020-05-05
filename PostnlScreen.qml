import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;
import SimpleXmlListModel 1.0
import FileIO 1.0

Screen {
	id: postnlScreen
	screenTitle: "Recente PostNL pakketten"

	property string actualModelText
	property string lastupdate
	property bool postnlLoaded : false

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
		if (app.postnlShowHistoryInMonths == 1) {
			actualModelText = "Pakketpost van de afgelopen maand:"
		} else {
			actualModelText = "Pakketpost van de afgelopen " + app.postnlShowHistoryInMonths + " maanden:"
		}
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

		var postNLXML = "<item>";

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
				postNLXML = postNLXML + "<parcel><deliveryDate>" + shipmentDate + "</deliveryDate><deliveryInfo>" + formatDelivery(postNLData['receiver'][i]['delivery']['status'], shipmentDate) + "</deliveryInfo><barcode>" + postNLData['receiver'][i]['barcode'] + "</barcode><senderInfo>" + shipmentTitle + shipmentSender + "</senderInfo></parcel>";
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
				postNLXML = postNLXML + "<parcel><deliveryDate>" + shipmentDate + "</deliveryDate><deliveryInfo>" + formatDelivery(postNLData['sender'][j]['delivery']['status'], shipmentDate) + "</deliveryInfo><barcode>" + postNLData['sender'][j]['barcode'] + "</barcode><senderInfo>" + "Verstuurd naar " + postNLData['sender'][j]['originalReceiver']['street'] + " " + postNLData['sender'][j]['originalReceiver']['houseNumber'] + ", " + postNLData['sender'][j]['originalReceiver']['town'] + "</senderInfo></parcel>";
			}
		}
		postNLXML = postNLXML + "</item>";
		postnlModel.xml = postNLXML;
		postnlSimpleList.initialView();
		postnlLoaded = true;
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

	SimpleXmlListModel {
		id: postnlModel
		query: "/item/parcel"
		roles: ({
			deliveryDate: "string",
			deliveryInfo: "string",
			barcode: "string",
			senderInfo: "string"
		})
	}

	Rectangle {
		id: content
		anchors.horizontalCenter: parent.horizontalCenter
		width: parent.width - 20
		height: isNxt ? parent.height - 74 : parent.height - 59
		y: isNxt ? 64 : 51
		x: 10
		radius: 3

		PostnlSimpleList {
			id: postnlSimpleList
			delegate: PostnlScreenDelegate{}
			dataModel: postnlModel
			itemHeight: isNxt ? 30 : 23
			itemsPerPage: 7
			anchors.top: parent.top
			downIcon: "qrc:/tsc/arrowScrolldown.png"
			buttonsHeight: isNxt ? 180 : 144
			buttonsVisible: true
			scrollbarVisible: true
		}

		Throbber {
			id: refreshThrobber
			anchors.centerIn: parent
			visible: !postnlLoaded
		}
	}
}
