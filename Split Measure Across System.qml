import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins." + qsTr("System Spacing") + "." + qsTr("Split Measure Across System")
    description: qsTr("Splits a measure across a system, saving a few clicks.") + "\n" +
        qsTr("Requires MuseScore 3.3 or later")
    version: "1.0"
    requiresScore: true

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            title = qsTr("Split Measure Across System")
        }
    }

    onRun: {
        // close the plugin if theres no selection
        if (! curScore.selection.elements.length) {
            smartQuit()
        }

        curScore.startCmd()

        // Split the measure, with the start of the selection ending up on the next system
        var tick = getTick(curScore.selection.elements[0])
        console.log(tick)
        var c = curScore.newCursor()
        c.rewindToTick(tick)
        var m = c.measure
        // Don't split measures if the first point in a measure is selected (the rest of the plugin is allowed to run regardless)
        if (tick != m.firstSegment.tick) {
            cmd('split-measure')
        }

        // Don't count the newly created 'measure' in the measure count
        c.rewindToTick(tick)
        m = c.measure
        m.irregular = true

        //move to the previous measure and add the system break
        while (c.measure.is(m)) {
            c.prev()
        }
        var systemBreak = newElement(Element.LAYOUT_BREAK)
        systemBreak.layoutBreakType = LayoutBreak.LINE
        systemBreak.score = curScore
        c.add(systemBreak.clone())

        //hide all the barlines
        m = c.measure
        for (var i = 0; i < curScore.nstaves; i++) {
            c.rewindToTick(m.firstSegment.tick)
            c.staffIdx = i
            c.filter = Segment.BarLineType
            c.next()
            c.element.visible = false
            c.filter = Segment.ChordRest
        }

        curScore.endCmd()
        smartQuit()
    }

    function getTick(element) {
        //note: split measures command currently only works with note/rest
        switch (element.type) {
            case Element.NOTE: {
                return element.parent.parent.tick
            }
            case Element.ARTICULATION: {
                return element.parent.parent.tick
            }
            default: {
                return element.parent.tick
                //should work for chord, rest, staff text, dynamics, fermatae
            }
        }
    }//getTick

    function smartQuit() {
        if (mscoreMajorVersion < 4) {
            Qt.quit()
        } else {
            quit()
        }
    }//smartQuit
}//MuseScore