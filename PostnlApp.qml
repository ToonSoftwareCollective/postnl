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
	property int postnlUpdateFrequencyInMinutes : 120
	property int postnlShowHistoryInMonths : 1

	property string tileBarcode : "even geduld a.u.b"
	property string tileSender
	property string tileDate
	property string tileTime

	// user settings from config file

	FileIO {
		id: postnlSettingsFile
		source: "file:///mnt/data/tsc/postnl.userSettings.json"
 	}


	Component.onCompleted: {
		// read user settings

		try {
			var postnlSettingsJson = JSON.parse(postnlSettingsFile.read());
			if (postnlSettingsJson['TrayIcon'] == "Yes") {
				enableSystray = true
			} else {
				enableSystray = false
			}
			postnlUserid = postnlSettingsJson['Userid'];		
			postnlPassword = postnlSettingsJson['Password'];
			if (postnlSettingsJson['UpdateFrequencyInMinutes']) postnlUpdateFrequencyInMinutes = postnlSettingsJson['UpdateFrequencyInMinutes'];		
			if (postnlSettingsJson['ShowHistoryInMonths']) postnlShowHistoryInMonths = postnlSettingsJson['ShowHistoryInMonths'];		
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
			"Password" : postnlPassword,
			"UpdateFrequencyInMinutes" : postnlUpdateFrequencyInMinutes,
			"ShowHistoryInMonths" : postnlShowHistoryInMonths
		}

  		var doc3 = new XMLHttpRequest();
   		doc3.open("PUT", "file:///mnt/data/tsc/postnl.userSettings.json");
   		doc3.send(JSON.stringify(tmpUserSettingsJson ));

		postnlDataRefreshTimer.stop();
		postnlDataRefreshTimer.interval = 1000;
		postnlDataRefreshTimer.start();

		postnlTimer.stop();
		postnlTimer.interval = 120000;
		postnlTimer.start();
	}

	Timer {
		id: postnlTimer
		interval: 180000  // first update after 3 minutes
		triggeredOnStart: false
		running: false
		repeat: true
		onTriggered: {
			interval = postnlUpdateFrequencyInMinutes * 60000;	
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
			interval = postnlUpdateFrequencyInMinutes * 60000;	
 			var doc4 = new XMLHttpRequest();
  			doc4.open("PUT", "file:///tmp/tsc.command");
   			doc4.send("postnl");
		}
	}
}
