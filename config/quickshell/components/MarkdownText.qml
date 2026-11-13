// components/MarkdownText.qml

import QtQuick
import QtQuick.Controls

import "root:/themes"
import "root:/utils/Markdown.js" as Markdown

/**
 * Renders a markdown source string with the active theme.
 *
 * The rendering is done by Qt's own markdown dialect (Text.MarkdownText) in a
 * *single* Text element - no per block items, no Loader, no Repeater. That
 * keeps the scene graph flat (important inside scrolling lists) and avoids
 * the scroll stutter caused by nodes being created/destroyed while the view
 * scrolls.
 *
 * Plain strings that contain no markdown marker take a fast path and are
 * rendered with Text.PlainText - no parsing at all.
 */
Item {
    id: root

    // --- Content ---------------------------------------------------------
    property string source: ""

    // --- Typography ------------------------------------------------------
    readonly property var theme: ThemeManager.selectedTheme
    readonly property var colors: theme.colors
    readonly property var typo: theme.typography

    property int baseFontSize: typo.medium
    property color textColor: colors.onSurface
    property bool strikeThrough: false

    // --- Fast path -------------------------------------------------------
    readonly property bool plainText: !Markdown.hasMarkdown(source)

    // The rendered height.
    //
    // Note: for rich text the implicitHeight of the Text element does NOT
    // include the line height multiplier, so the last line would be clipped.
    // contentHeight is the real height of the laid out document.
    implicitHeight: contentText.contentHeight

    Text {
        id: contentText
        width: parent.width

        // prepareForQt flattens code blocks (they would never wrap in Qt) and
        // removes links with a protocol that is not allowed.
        text: root.plainText ? root.source : Markdown.prepareForQt(root.source)
        textFormat: root.plainText ? Text.PlainText : Text.MarkdownText

        // AlignAuto keeps the correct base direction for mixed Arabic/English
        // content instead of forcing a left/right alignment.
        horizontalAlignment: Text.AlignAuto
        wrapMode: Text.Wrap

        // Nothing may paint outside of the available width.
        clip: true

        font.family: root.typo.bodyFont
        font.pixelSize: root.baseFontSize
        font.strikeout: root.strikeThrough
        color: root.textColor
        lineHeight: 1.25
    }
}
