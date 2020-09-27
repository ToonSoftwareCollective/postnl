import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;
import SimpleXmlListModel 1.0
import FileIO 1.0

Screen {
	id: postnlScreen
	screenTitle: "Recente PostNL pakketten"

	property string actualModelText
	property string lastupdate : "even geduld...."
	property bool postnlLoaded : false
	property bool showReceived : true
	property string sentParcels
	property string receivedParcels

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
			actualModelText = "pakketten van de afgelopen maand: (" + lastupdate + ")"
		} else {
			actualModelText = "pakketten van de afgelopen " + app.postnlShowHistoryInMonths + " maanden: (" + lastupdate + ")"
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
		app.tileParcelName = "";

			// read inbox

		var postNLData = JSON.parse(postnlInboxFile.read());
		if (postNLData['receiver'].length > 0) {

				//format tile when parcel is coming
			if ((postNLData['receiver'][0]['delivery']['status'] !== 'Delivered') && (postNLData['receiver'][0]['shipmentType'] !== 'Pending')) {
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
				if (app.enableUseCustomParcelName == true && postNLData['receiver'][0]['trackedShipment']['title']) {
					app.tileParcelName = postNLData['receiver'][0]['trackedShipment']['title'];
				}

			}
		}

			// fill screen

		receivedParcels = "<item>";
		sentParcels = "<item>";

		var shipmentDate = "";
		var shipmentSender = "";
		var shipmentTitle = "";
		var tileParcelName = "";

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

			if (postNLData['receiver'][i]['shipmentType'] !== 'Pending') {

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
						if (postNLData['receiver'][i]['delivery']['status'] == 'InTransit') {
							shipmentTitle = "Zending ontvangen door PostNL, van ";
						} else {
							shipmentTitle = "Te ontvangen van ";
						}
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
	
					if (app.enableUseCustomParcelName == true && postNLData['receiver'][i]['trackedShipment']['title']) {
						tileParcelName = postNLData['receiver'][i]['trackedShipment']['title'] + " - " + postNLData['receiver'][i]['barcode'];
					} else {
						tileParcelName = postNLData['receiver'][i]['barcode'];
					}
					receivedParcels = receivedParcels + "<parcel><deliveryDate>" + shipmentDate + "</deliveryDate><deliveryInfo>" + formatDelivery(postNLData['receiver'][i]['delivery']['status'], shipmentDate) + "</deliveryInfo><barcode>" + tileParcelName + "</barcode><senderInfo>" + shipmentTitle + shipmentSender + "</senderInfo></parcel>";
				}
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
				sentParcels = sentParcels + "<parcel><deliveryDate>" + shipmentDate + "</deliveryDate><deliveryInfo>" + formatDelivery(postNLData['sender'][j]['delivery']['status'], shipmentDate) + "</deliveryInfo><barcode>" + postNLData['sender'][j]['barcode'] + "</barcode><senderInfo>" + "Verstuurd naar " + postNLData['sender'][j]['originalReceiver']['street'] + " " + postNLData['sender'][j]['originalReceiver']['houseNumber'] + ", " + postNLData['sender'][j]['originalReceiver']['town'] + "</senderInfo></parcel>";
			}
		}
		receivedParcels = receivedParcels + "</item>";
		sentParcels = sentParcels + "</item>";

		postnlModel.xml = receivedParcels;
		showReceived = true;
		postnlSimpleList.initialView();
		postnlLoaded = true;
	}

	Item {
		id: header
		height: isNxt ? 55 : 45
		width: parent.width

		StandardButton {
			id: showParcelType
			height: isNxt ? 40 : 32
			text: (showReceived) ? "Ontvangen " : "Verstuurde "
			fontPixelSize: isNxt ? 25 : 20
			color: colors.background
			anchors {
				bottom: parent.bottom
				left: parent.left
				leftMargin : 10
			}

			onClicked: {
				if (showReceived) {
					showReceived = false;
					postnlModel.xml = sentParcels;
				} else {
					showReceived = true;
					postnlModel.xml = receivedParcels;
				}
				postnlSimpleList.initialView();
			}
		}

		Text {
			id: headerText
			text: actualModelText
			font.family: qfont.semiBold.name
			font.pixelSize: isNxt ? 25 : 20
			anchors {
				left: showParcelType.right
				leftMargin: isNxt ? 16 : 12
				top: showParcelType.top
				topMargin : isNxt ? 4 : 3
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
		height: isNxt ? parent.height - 74 : parent.height - 49
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
