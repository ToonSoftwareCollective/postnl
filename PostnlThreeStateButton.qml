import QtQuick 2.1
import BasicUIControls 1.0

/**
  ThreStateButton implements button with 3 defined states: "up", "down" and "disabled". Clickable area with
  size of the button is created and filled with background color (backgroundUp property).
  Button hold only the image (no text). Original image can be rotated using 'imgRotation' property.
  For image placed on the button shadow is created (moving original image [+2; +2] with opacity 20%.
  Disabled button has no shadow for the icon and color effect is applied on the original image.
  States "up" and "down" are handled via mouse click. Icon and button background is different for the statess.
  State disabled has to be raised by user calling ThreeStateButton.disable(). Enabling of the button is done
  by ThreeStateButton.enable(). This is not a new state - if button is enabled state "up" is used.

  */

Item {
	id: threeStateButton
	width: 50
	height: 50

	property url image
	property color backgroundUp
	property color backgroundDown
	property int imgRotation: 0
	property color buttonDownColor
	property int iconBottomMargin
	property alias color: buttonWrap.color
	property alias bottomClickMargin: buttonWrap.bottomClickMargin
	property alias topClickMargin: buttonWrap.topClickMargin
	property alias leftClickMargin: buttonWrap.leftClickMargin
	property alias rightClickMargin: buttonWrap.rightClickMargin
	property string kpiPostfix: image.toString().split("/").pop().split(".").shift() + imgRotation

	property bool enabled: true
	onEnabledChanged: {
		if(enabled)
			threeStateButton.state = "up"
		else
			threeStateButton.state = "disabled"
	}

	signal clicked;

	onIconBottomMarginChanged: {
		icon.anchors.bottomMargin = iconBottomMargin
		iconDisabled.anchors.bottomMargin = iconBottomMargin
	}

	StyledRectangle {
		id: buttonWrap
		width: threeStateButton.width
		height: threeStateButton.height
		color: backgroundUp
		onPressed: threeStateButton.state = "down"
		onReleased: threeStateButton.state = "up"
		onClicked: threeStateButton.clicked()
	}

	Image {
		id: icon
		rotation: imgRotation
		anchors.horizontalCenter: parent.horizontalCenter
		source: image
		anchors.bottom: parent.bottom
		anchors.bottomMargin: 0
	}

	Image {
		id: iconDisabled
		rotation: imgRotation
		anchors.left: icon.left
		anchors.top: icon.top
		source: image
		opacity: 0.8
		visible: false
	}

	states: [
		State {
			name: "up"
			PropertyChanges {
				target: icon
				visible: true
			}
			PropertyChanges {
				target: iconDisabled
				visible: false
			}
			PropertyChanges {
				target: buttonWrap
				mouseEnabled: true
			}
		},
		State {
			name: "down"
			PropertyChanges {
				target: icon
				visible: true
			}
			PropertyChanges {
				target: effectDown
				enabled: true
			}
			PropertyChanges {
				target: buttonWrap
				color: backgroundDown
			}
		},
		State {
			name: "disabled"
			PropertyChanges {
				target: icon
				visible: false
			}
			PropertyChanges {
				target: iconDisabled
				visible: true
			}
			PropertyChanges {
				target: buttonWrap
				mouseEnabled: false
			}
		},
		State {
			name: "hidden"
			PropertyChanges {
				target: icon
				visible: false
			}
			PropertyChanges {
				target: buttonWrap
				mouseEnabled: false
			}
		}
	]
}
