import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import FileIO 1.0

App {
	id: postnlApp

	property url tileUrl : "PostnlTile.qml";
	property url thumbnailIcon: "qrc:/tsc/postnl.png";
	property url postnlScreenUrl : "PostnlScreen.qml"
	property url postnlConfigurationScreenUrl : "PostnlConfigurationScreen.qml"
	property url trayUrl : "PostnlTray.qml";

	property PostnlConfigurationScreen postnlConfigurationScreen
	property PostnlScreen postnlScreen

	property string timeStr
	property string dateStr
	property bool enableSystray
	property bool loggedIn : false

	property variant accessTokenJson
	property variant postNLData
	property variant lettersData
	property variant letterDetails
	property string letterImageUrl : "qrc:/tsc/refresh.svg"

	property string postnlUserid
	property string postnlPassword
	property string staticKey

	property string tileBarcode : "even geduld a.u.b"
	property string tileSender
	property string tileDate
	property string tileTime

	// user settings from config file
	property variant postnlSettingsJson : {
		'Userid': [],
		'Password': "",
		'TrayIcon': ""
	}

	FileIO {
		id: postnlSettingsFile
		source: "file:///mnt/data/tsc/postnl.userSettings.json"
 	}

	Component.onCompleted: {
		// read user settings

		try {
			postnlSettingsJson = JSON.parse(postnlSettingsFile.read());
			if (postnlSettingsJson['TrayIcon'] == "Yes") {
				enableSystray = true
			} else {
				enableSystray = false
			}
			postnlUserid = postnlSettingsJson['Userid'];		
			postnlPassword = postnlSettingsJson['Password'];		
		} catch(e) {
		}

		postnlTimer.start();
	}

	// Postnl signals, used to update the listview and filter enabled button
	signal postnlUpdated()

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("PostNL"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", postnlScreenUrl, this, "postnlScreen");
		registry.registerWidget("screen", postnlConfigurationScreenUrl, this, "postnlConfigurationScreen");
		registry.registerWidget("systrayIcon", trayUrl, this, "postnlTray");
	}

	function refreshPostNLData() {

			// clear Tile
		tileDate =  "";
		tileTime =  "";
		tileBarcode = "Bezig met inloggen.....";
		tileSender = "";
		letterImageUrl = "";

			// step 1 , get static key

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("GET", "https://jouw.postnl.nl/?pst=k-pnl_f-f_p-pnl_u-txt_s-pwb_r-pnlinlogopties_v-jouwpost", true);
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
				var response = xmlhttp.responseText;
				var i = response.indexOf("/static/");
				var j = response.indexOf("'", i);
				refreshPostNLDataStep2(response.substring(i + 8, j));
			}
		}
		xmlhttp.send();
	}

	function refreshPostNLDataStep2(staticKey) {

//		console.log("********* PostNL static key:" + staticKey);

       		var params = '{"sensor_data":"101213114115"}';
		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("POST", "https://jouw.postnl.nl/static/" + staticKey, true);
        	xmlhttp.setRequestHeader("Content-type", "text/plain;charset=UTF-8");
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
//				console.log("********* PostNL access request step 2 response:" + xmlhttp.responseText);
				refreshPostNLDataStep3();
			}
		}
		xmlhttp.send(params);
	}

	function refreshPostNLDataStep3() {

       		var params = "grant_type=password&client_id=pwWebApp&username=" + postnlUserid + "&password=" + postnlPassword + "&role=customer";
		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("POST", "https://jouw.postnl.nl/web/token", true);
        	xmlhttp.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
        	xmlhttp.setRequestHeader("Content-length", params.length);
        	xmlhttp.setRequestHeader("Connection", "close");
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
				var d = new Date().toLocaleTimeString();
//				console.log("********* PostNL access request:" + d);
//				console.log("********* PostNL access request:" + xmlhttp.responseText);
				if (xmlhttp.responseText.indexOf("Access Denied") < 1) {
					accessTokenJson	= JSON.parse(xmlhttp.responseText); 
					if (accessTokenJson['error'] !== "accountnotfound") {
						tokenRefreshTimer.start();
						postnlTimer.stop();
						console.log("********* PostNL token refresh timer started");
						loggedIn = true;
						tileBarcode = "Geen pakketten verwacht";
						readInbox(1);
						readLetters();
					}
				} else {
					console.log("********* PostNL app: Access Denied at " + d);
				}
			}
		}
		xmlhttp.send(params);
	}

	function refreshPostNLToken() {

       		var params = "grant_type=refresh_token&client_id=pwWebApp&refresh_token=" + accessTokenJson['refresh_token'];
		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("POST", "https://jouw.postnl.nl/web/token", true);
        	xmlhttp.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
        	xmlhttp.setRequestHeader("Content-length", params.length);
        	xmlhttp.setRequestHeader("Connection", "close");
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
				var d = new Date().toLocaleTimeString();
//				console.log("********* PostNL access refresh:" + d);
//				console.log("********* PostNL access refresh:" + xmlhttp.responseText);
				if (xmlhttp.responseText.indexOf("refresh_token") > 1) {
					tokenRefreshTimer.start();
					postnlTimer.stop();
					accessTokenJson	= JSON.parse(xmlhttp.responseText); 
					readInbox(1);
					readLetters();
				} else {
					console.log("********* PostNL app token refresh failed. Trying requesting new token at:" + d);
					tokenRefreshTimer.stop();
					postnlTimer.start();
					refreshPostNLData();
				}
			}
		}
		xmlhttp.send(params);
	}

	function readInbox(attempt) {  

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("GET", "https://jouw.postnl.nl/web/api/default/inbox", true);
       		xmlhttp.setRequestHeader("Authorization", "Bearer "+ accessTokenJson['access_token']);
       	 	xmlhttp.setRequestHeader("Connection", "close");
 		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
				saveInbox(xmlhttp.responseText);
				var response = xmlhttp.responseText

					// check for timeout (usually happens with large inboxes at the server side), retry once
				if (response.indexOf("InboxStatusException") > 1) {
					console.log("********* PostNL InboxStatusException:" + attempt);
					if (attempt == 1) {
						readInbox(2);
					}
				} else {
					postNLData = JSON.parse(xmlhttp.responseText);
					if (postNLData['receiver'].length > 0) {

							//format tile when parcel is coming
						if (postNLData['receiver'][0]['delivery']['status'] !== 'Delivered') {
							if (postNLData['receiver'][0]['delivery']['timeframe']['from']) {
								tileDate =  postNLData['receiver'][0]['delivery']['timeframe']['from'].substring(0,10);
								tileTime =  postNLData['receiver'][0]['delivery']['timeframe']['from'].substring(11,16) +  " - " + postNLData['receiver'][0]['delivery']['timeframe']['to'].substring(11,16);
							} else {
								tileDate =  " ";
								tileTime =  " ";
							}
							tileBarcode = postNLData['receiver'][0]['barcode'];
							if (postNLData['receiver'][0]['sender']['companyName']) {
								tileSender = postNLData['receiver'][0]['sender']['companyName'];
							}
						}
						postnlScreen.refreshScreen(); 
					}
				}
			}
		}
		xmlhttp.send();
	}

	function readLetters() {

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("GET", "https://jouw.postnl.nl/mobile/api/letters", true);
       	 	xmlhttp.setRequestHeader("Authorization", "Bearer "+ accessTokenJson['access_token']);
       	 	xmlhttp.setRequestHeader("Connection", "close");
      	 	xmlhttp.setRequestHeader("Api-Version", "4.6");
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
				lettersData = JSON.parse(xmlhttp.responseText);
			}
		}
		xmlhttp.send();
	}

	function saveInbox(text) {
		
  		var doc3 = new XMLHttpRequest();
   		doc3.open("PUT", "file:///var/volatile/tmp/postnl_inbox.json");
   		doc3.send(text);
	}

	function saveSettings() {
		
		// save user settings

		var tmpTrayIcon = "";
		if (enableSystray == true) {
			tmpTrayIcon = "Yes";
		} else {
			tmpTrayIcon = "No";
		}

 		var tmpUserSettingsJson = {
			"Userid" : postnlUserid,
			"TrayIcon" : tmpTrayIcon,
			"Password" : postnlPassword
		}

  		var doc3 = new XMLHttpRequest();
   		doc3.open("PUT", "file:///mnt/data/tsc/postnl.userSettings.json");
   		doc3.send(JSON.stringify(tmpUserSettingsJson ));

		refreshPostNLData();
	}

	Timer {
		id: postnlTimer
		interval: 60000  // first update after 1 minutes
		triggeredOnStart: false
		running: false
		repeat: true
		onTriggered: {
			interval = 600000 //10 minute retry rate untill a valid access token is received	
			refreshPostNLData()
		}
	}

	Timer {
		id: tokenRefreshTimer
		interval: 1700000  // within 30 minutes
		triggeredOnStart: false
		running: false
		repeat: false
		onTriggered: {
			refreshPostNLToken();
		}
	}
}
