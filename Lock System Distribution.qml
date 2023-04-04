import QtQuick 2.0
import MuseScore 3.0

MuseScore {
	menuPath: "Plugins." + qsTr("System Spacing") + "." + qsTr("Lock System Distribution")
	description: qsTr("Fixes in place the measures per system and systems per page") + "\n" +
		qsTr("Requires MuseScore 3.3 or later") + "\n" +
		qsTr("Currently non-functional in MuseScore 4")
	version: "1.0"
	requiresScore: true
	//To Do: Respect Frames?
	
	Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
            title = qsTr("Lock System Distribution")
        }
    }//Component
	
	property var mno
	property var cursor
	
	onRun: {
		curScore.startCmd()
		
		cursor = curScore.newCursor()
		
		var systemBreak = newElement(Element.LAYOUT_BREAK)
		systemBreak.layoutBreakType = LayoutBreak.LINE
		systemBreak.score = curScore
		
		var pageBreak = newElement(Element.LAYOUT_BREAK)
		pageBreak.layoutBreakType = LayoutBreak.PAGE
		pageBreak.score = curScore
		
		var prevSystem
		var curSystem
		var prevPage
		var curPage
		
		var systems = []
		var pages = []
		
		cursor.rewind(Cursor.SCORE_START)
		mno = 0
		addConsoleBreak()
		console.log("Scanning Score")
		do {
			mno += 1
			//Hierarchy: NoteRest/Segment/Measure/System/Page/Undefined
			curSystem = cursor.measure.parent.posY //system's position
			curPage = cursor.measure.parent.parent.pagenumber //page number
			
			if (curSystem !== prevSystem) {
				if (measureIsEmpty(cursor.measure)) {
					systems.push(mno)
				}
				console.log("found system change: measure " + mno)
			}
			
			if (curPage !== prevPage) {
				if (measureIsEmpty(cursor.measure)) {
					pages.push(mno)
				}
				console.log("found page change: measure " + mno)
			}
			console.log("measure " + mno + ", system " + systems.length + ", page " + pages.length)
			
			prevSystem = cursor.segment.parent.parent.posY
			prevPage = cursor.segment.parent.parent.parent.pagenumber
			
		} while (cursor.nextMeasure())
		
		cursor.rewind(Cursor.SCORE_START)
		mno = 0
		addConsoleBreak()
		console.log("Adding Layout Breaks")
		do {
			mno += 1
			addSuitableBreaks(systems, systemBreak, "system")
			addSuitableBreaks(pages, pageBreak, "page")
		} while (cursor.nextMeasure())
		
		curScore.endCmd()
		smartQuit()
	}//onRun
	
	function addSuitableBreaks(layoutType, breakType, message) {
		for (var i in layoutType) {
			if (layoutType[i] == (mno+1) && mno != 1) {
				console.log("adding " + message + " break to measure " + mno)
				cursor.add(breakType.clone())
			}
		}
	}//addSuitableBreaks
	
	function measureIsEmpty(measure) {
		if (mno == 1) {
			return true
		}
		var check = true
		for (var i in measure.prevMeasure.elements) {
			if (measure.prevMeasure.elements[i].type == Element.LAYOUT_BREAK) {
				check = false
				console.log("Detected existing Layout Break between measures " + (mno-1) + "-" + mno)
			}
		}
		return check
	}//measureIsEmpty
	
	function addConsoleBreak() {console.log("--------------------------------")}
	
	function smartQuit() {
		if (mscoreMajorVersion < 4) {Qt.quit()}
		else {quit()}
	}//smartQuit
}//MuseScore
