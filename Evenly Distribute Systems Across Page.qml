import QtQuick 2.0
import MuseScore 3.0
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.0

MuseScore {
	menuPath: "Plugins." + qsTr("System Spacing") + "." + qsTr("Evenly Distribute Systems Across Pages")
	description: qsTr("Evenly spreads systems across pages") + "\n" +
		qsTr("Requires MuseScore 3.3 or later")
	version: "1.0"
	requiresScore: true
	
	property int spacing: 10
	
	property var wideSpacing: false
	property var lastPageSmoothing: false
	
	Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
            title = qsTr("Evenly Distribute Systems Across Pages")
        }
		//MuseScore 4 detects and runs the plugin, but no visible changes are made
		//NOT due to layoutBreakType enum
    }//Component
	
	onRun: {dialog.visible = true}
	
	function runPlugin(minSPP, maxSPP, maxSPP1) {
		curScore.startCmd()
		
		if (applyAutoSpacing) {
			curScore.style.setValue("enableVerticalSpread", 1)
		}
		
		var cursor = curScore.newCursor()
		
		var pageBreak = newElement(Element.LAYOUT_BREAK)
		pageBreak.layoutBreakType = LayoutBreak.PAGE
		pageBreak.score = curScore
		
		var systemBreak = newElement(Element.LAYOUT_BREAK)
		systemBreak.layoutBreakType = LayoutBreak.LINE
		systemBreak.score = curScore
		
		var prevSystem
		var curSystem
		var prevPage
		var curPage
		
		var systems = []
		var pages = []
		
		cursor.rewind(Cursor.SCORE_START)
		var mno = 0
		addConsoleBreak()
		console.log("Scanning Score")
		while (true) {
			mno += 1
			//Hierarchy: NoteRest/Segment/Measure/System/Page/Undefined
			curSystem = cursor.measure.parent
			curPage = curSystem.parent
			
			for (var i in cursor.measure.elements) {
				var element = cursor.measure.elements[i]
				if (element.type == Element.LAYOUT_BREAK && element.layoutBreakType == LayoutBreak.PAGE) {
					removeElement(element)
					cursor.add(systemBreak.clone())
					console.log("Replaced existing page break between measures " + mno + "-" + (mno+1))
				}
			}
			
			if (! curSystem.is(prevSystem)) {
				systems.push(mno)
				if (! curPage.is(prevPage)) {
					pages.push(mno)
					console.log("Detected page change: Measure " + mno + ", system " + systems.length + ", page " + pages.length)
				} else {
					console.log("Detected system change: Measure " + mno + ", system " + systems.length)
				}
			}
			
			prevSystem = cursor.measure.parent
			prevPage = prevSystem.parent
			
			if (! cursor.nextMeasure()) {
				break
			}
		}//Scan Score
		
		var distribution = calculateDistribution(systems.length, minSPP, maxSPP, maxSPP1)
		
		cursor.rewind(Cursor.SCORE_START)
		mno = 0
		curSystem = 0
		addConsoleBreak()
		console.log("Applying New Layout")
		do {
			mno += 1
			for (var i in systems) {
				if (systems[i] == (mno+1)) {
					curSystem += 1
					for (var j in distribution) {
						if (distribution[j] == curSystem) {
							console.log("adding page break to measure " + mno + ", system " + curSystem)
							//remove existing breaks of all kinds in same location
							for (var i in cursor.measure.elements) {
								if (cursor.measure.elements[i].type == Element.LAYOUT_BREAK) {
									removeElement(cursor.measure.elements[i])
									console.log("replaced existing layout break")
								}
							}
							cursor.add(pageBreak.clone())
						}
					}
				}
			}
		} while (cursor.nextMeasure())
		
		curScore.endCmd()
		smartQuit()
	}//onRun
	
	function calculateDistribution(nSystems, minSPP, maxSPP, maxSPP1) {
		addConsoleBreak()
		
		var pageModel = [] //Array that contains the number of systems per page
		var remainingSystems = nSystems //used to track unassigned systems
		
		wideSpacing = settings.wideSpacing
		lastPageSmoothing = settings.lastPageSmoothing
		
		if (nSystems <= maxSPP1) {
			console.log("The Resulting Score is 1 Page long.")
			pageModel = false
		} else
		if (wideSpacing) {
			//respect minSPP at all costs, but not maxSPP and maxSPP1
			
			var maxNPages = Math.floor(nSystems/minSPP)
			//this is the maximum number of pages while respecting minSPP
			
			//add minSPP pages to every page
			for (var i = 0; i < maxNPages; i++) {
				pageModel.push(minSPP)
				remainingSystems -= pageModel[i]
			}
			
			//distribute the remaining systems (if any) 
			while (remainingSystems != 0) {
				for (var i = 0; i < maxNPages; i++) {
					var i2 = (i+1) % maxNPages //skip first page on first assignment
					if (i2 > 0 || pageModel[i2] < maxSPP1) {
						pageModel[i2] += 1
						remainingSystems -= 1
					}
					if (remainingSystems == 0) {
						break
					}
				}
			}//while remainingSystems
			
		} else {
			//respect maxSPP and maxSPP1 at all costs, but not minSPP
			
			var minNPages = Math.ceil((nSystems-maxSPP1) / maxSPP) + 1
			//this is the lowest possible number of pages while respecting maxSPP and maxSPP1
			
			//in an evenly-as-possibly distributed score, the minimum systems per page is this number
			var base = Math.floor(nSystems / minNPages)
			
			//On the first page, either put the smallest number of systems that doesn't affect page number, or the allowed maximum
			pageModel.push(Math.min(base, maxSPP1))
			remainingSystems -= pageModel[0]
			
			//add as many systems to the other pages as possible, provided they all have the same amount
			for (var i = 1; i < minNPages; i++) {
				pageModel.push(base)
				remainingSystems -= pageModel[i]
			}
			
			//distribute the remaining systems (if any) 
			while (remainingSystems != 0) {
				for (var i = 1; i < minNPages; i++) {
					pageModel[i] += 1
					remainingSystems -= 1
					if (remainingSystems == 0) {
						break
					}
				}
			}//while remainingSystems
			
			//if desired, move systems from the end of the score to the front until they all reach minSPP
			//this will mean only the last page will have fewer systems than minSPP
			if (! lastPageSmoothing) {
				for (var i = 0; i < minNPages-1; i++) {
					while (pageModel[i] < minSPP) {
						pageModel[pageModel.length-1] -= 1
						pageModel[i] += 1
					}
				}
			}//lastPageSmoothing
			
		}//Regular Spacing
		
		console.log("Calculated Systems per Page: " + pageModel.toString())
		
		//turn pageModel into a readable format (absolute instead of relative system values)
		for (var i = 1; i < pageModel.length; i++) {
			pageModel[i] += pageModel[i-1]
		}
		
		return pageModel
	}//calculateDistribution
	
	ApplicationWindow {
		id: dialog
		title: qsTr("System Spacer")
		flags: Qt.Dialog
		
		Component.onCompleted: {
			height += spacing
			width += spacing
			maximumHeight = height
			minimumHeight = height
			maximumWidth = width
			minimumWidth = width
		}
		
		ColumnLayout {
			x: spacing * 2
			y: spacing * 2
			anchors.margins: spacing
			spacing: spacing
			
			GridLayout {
				anchors.margins: spacing
				rowSpacing: spacing
				columnSpacing: spacing
				columns: 2
				
				Label {text: qsTr("Min. Number of Systems per Page:")}
				
				SpinBox {id: minSPPBox; minimumValue: 1; value: 4
					implicitWidth: 60; implicitHeight: 30;}//SpinBox
				
				Label {text: qsTr("Max. Number of Systems per Page:")}
				
				SpinBox {id: maxSPPBox; minimumValue: 1; value: 6
					implicitWidth: 60; implicitHeight: 30;}//SpinBox
				
				Label {text: qsTr("Max. Number of Systems on First Page:")}
				
				SpinBox {id: maxSPP1Box; minimumValue: 1; value: 5
					implicitWidth: 60; implicitHeight: 30;}//SpinBox
			}//GridLayout
			
			/*Label {
				id: errorMessage
				visible: (minSPPBox.value > maxSPP1Box.value || maxSPP1Box.value > maxSPPBox.value)
				text: qsTr("Error: Invalid Input") + "\n" + qsTr("Min. =< Page 1 Max. =< Max.")
				color: "red"
			}//Label*/
			
			RowLayout {
				anchors.margins: 0
				anchors.right: parent.right
				spacing: spacing
				
				Button {
					id: optionsButton
					text: qsTr("Options")
					onClicked: optionsDialog.open()
				}
				
				Button {
					id: cancelButton
					text: qsTr("Cancel")
					onClicked: {
						dialog.close()
						smartQuit()
					}
				}//leftbutton
						
				Button {
					id: okButton
					text: qsTr("OK")
					enabled: ! (minSPPBox.value > maxSPP1Box.value || maxSPP1Box.value > maxSPPBox.value)
					opacity: enabled ? 1.0 : 0.5
					onClicked: {
						dialog.close()
						runPlugin(minSPPBox.value, maxSPPBox.value, maxSPP1Box.value)
					}
				}//rightbutton
			}//rowlayout
		}//ColumnLayout
	}//ApplicationWindow
	
	Dialog {
		id: optionsDialog
		title: "System Spacer: Options"
		
		ColumnLayout {
			anchors.margins: spacing
			spacing: spacing
			
			GroupBox {
				title: qsTr("Spacing Mode")
				
				ExclusiveGroup {id: spacingEx}
				
				RowLayout {
					anchors.margins: spacing
					spacing: spacing
					
					RadioButton {
						id: wideButton
						text: qsTr("Wide")
						exclusiveGroup: spacingEx
					}
					
					RadioButton {
						id: regularButton
						text: qsTr("Regular")
						exclusiveGroup: spacingEx
						checked: true
					}
					
					RadioButton {
						id: compactButton
						text: qsTr("Compact")
						exclusiveGroup: spacingEx
					}
				}//ColumnLayout
			}//GroupBox
			
			CheckBox {
				id: applyAutoSpacing
				visible: (mscoreMajorVersion >= 4 || (mscoreMajorVersion == 3 && mscoreMinorVersion >= 6))
				checked: visible
				text: qsTranslate("Ms::MuseScore", "Enable vertical justification of staves")
			}//CheckBox
			
		}//ColumnLayout
		
		onAccepted: {
			settings.wideSpacing = wideButton.checked
			settings.lastPageSmoothing = ! compactButton.checked
			settings.applyAutoStyle = ((mscoreMajorVersion >= 4 || (mscoreMajorVersion == 3 && mscoreMinorVersion >= 6)) && applyAutoSpacing.checked)
			optionsDialog.close()
		}
	}//optionsDialog
	
	function smartQuit() {
		if (mscoreMajorVersion < 4) {Qt.quit()}
		else {quit()}
	}//smartQuit
	
	function addConsoleBreak() {console.log("--------------------------------")}
	
	Settings {
		id: settings
		category: "System Spacer Plugin"
		property alias minSPPBox:  minSPPBox.value
		property alias maxSPPBox:  maxSPPBox.value
		property alias maxSPP1Box: maxSPP1Box.value
		property alias wideButton: wideButton.checked
		property alias regularButton: regularButton.checked
		property alias compactButton: compactButton.checked
		property alias applyAutoSpacing: applyAutoSpacing.checked
		property var applyAutoStyle
		property var wideSpacing
		property var lastPageSmoothing
	}
}//MuseScore
