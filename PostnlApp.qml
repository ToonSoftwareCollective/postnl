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

	property string postnlUserid
	property string postnlPassword

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

		postnlDataRefreshTimer.start();
		postnlTimer.start();

		lastupdate = lastupdateFile.read();

	}

	// Postnl signals, used to update the listview and filter enabled button
	signal postnlUpdated()

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("PostNL"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", postnlScreenUrl, this, "postnlScreen");
		registry.registerWidget("screen", postnlConfigurationScreenUrl, this, "postnlConfigurationScreen");
		registry.registerWidget("systrayIcon", trayUrl, this, "postnlTray");
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
		interval: 180000  // first update after 3 minutes
		triggeredOnStart: false
		running: false
		repeat: true
		onTriggered: {
			interval = 7200000 //2 hour refresh rate (note input file is only refreshed every hour, so display can be delayed by two hours)	
			postnlScreen.refreshScreen(); 
		}
	}

	Timer {
		id: postnlDataRefreshTimer
		interval: 60000  // first update after 1 minutes
		triggeredOnStart: false
		running: false
		repeat: true
		onTriggered: {	// request tsc script to retrieve postnl inbox
			interval = 7200000 //2 hour refresh rate	
 			var doc4 = new XMLHttpRequest();
  			doc4.open("PUT", "file:///tmp/tsc.command");
   			doc4.send("postnl");
		}
	}
}
