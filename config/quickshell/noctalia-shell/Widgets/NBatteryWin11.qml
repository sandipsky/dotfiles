import QtQuick
import qs.Commons

// Windows 11 style battery glyph, rendered from the Segoe Fluent Icons font
// (installed system-wide by install.sh from assets/fonts/SegoeIcons.ttf).
//
// Ported one-to-one from the win11 branch's BatteryIndicator.qml:
// two stacked Text layers so only the interior level bars get tinted.
//   bottom = plain Battery1..10 decile glyph (outline + level bars, no
//            bolt/leaf) drawn in the fill color
//   top    = the matching "empty" frame of the active family (Battery0 /
//            BatteryCharging0 / BatterySaver0) drawn in the frame color —
//            covers the outline plus the bolt/leaf while leaving the
//            interior transparent so the colored bars below show through.
Item {
  id: root

  property real percentage: 0 // 0..100
  property bool charging: false // plugged-in states count as charging, like win11
  property bool powerSaver: false
  property bool ready: true
  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property color frameColor: Color.mOnSurface

  // Segoe Fluent battery glyphs sit lower in the em square than the tabler
  // icons every call site was sized for — scale up so the drawn battery
  // matches the apparent size of the tabler glyph it replaces.
  property real glyphScale: 1.3

  // Battery1..Battery10 (deciles), indexed 0..9
  readonly property var _levels: ["\uE851", "\uE852", "\uE853", "\uE854", "\uE855", "\uE856", "\uE857", "\uE858", "\uE859", "\uE83F"]

  readonly property string _fillGlyph: {
    if (!ready) {
      return "\uE996"; // BatteryUnknown
    }
    var idx = Math.max(0, Math.min(9, Math.ceil(percentage / 10) - 1));
    return _levels[idx];
  }

  // win11 fill tints: green while charging, amber in power-saver
  readonly property bool _tinted: ready && (charging || powerSaver)
  readonly property color _fillColor: !_tinted ? frameColor : (charging ? "#9fd89f" : "#eaa300")
  readonly property string _frameGlyph: charging ? "\uE85A" : (powerSaver ? "\uE863" : "\uE850")

  readonly property real _fontPointSize: Math.max(1, (applyUiScale ? pointSize * Style.uiScaleRatio : pointSize) * glyphScale)

  implicitWidth: fillText.implicitWidth
  implicitHeight: fillText.implicitHeight

  Text {
    id: fillText
    anchors.centerIn: parent
    text: root._fillGlyph
    color: root._fillColor
    font.family: "Segoe Fluent Icons"
    font.pointSize: root._fontPointSize
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
  }

  Text {
    anchors.centerIn: parent
    text: root._frameGlyph
    color: root.frameColor
    font.family: "Segoe Fluent Icons"
    font.pointSize: root._fontPointSize
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    visible: root._tinted
  }
}
