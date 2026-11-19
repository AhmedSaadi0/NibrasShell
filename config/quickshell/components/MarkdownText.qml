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
    // ThemeManager loads its theme asynchronously, so selectedTheme can be
    // null during startup and while a theme is being swapped.
    readonly property var theme: ThemeManager.selectedTheme || null
    readonly property var colors: theme ? theme.colors : null
    readonly property var typo: theme ? theme.typography : null

    property int baseFontSize: typo ? typo.medium : 14
    property color textColor: colors ? colors.onSurface : palette.text
    property bool strikeThrough: false

    // --- Fast path -------------------------------------------------------
    readonly property bool plainText: !Markdown.hasMarkdown(source)

    // Expose both dimensions: implicitWidth is the natural unwrapped width,
    // contentHeight is the real laid-out height of rich text (it includes the
    // line-height multiplier that implicitHeight omits).
    implicitWidth: contentText.implicitWidth
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

        font.family: root.typo ? root.typo.bodyFont : ""
        font.pixelSize: root.baseFontSize
        font.strikeout: root.strikeThrough
        color: root.textColor
        lineHeight: 1.25

        onLinkActivated: link => {
            // Qt has already parsed the href; validate it again at the point
            // where the external URL would actually be opened.
            if (Markdown.isSafeUrl(link))
                Qt.openUrlExternally(link);
        }

        HoverHandler {
            id: linkHover
            cursorShape: contentText.hoveredLink !== ""
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor
        }
    }
}
