// utils/Markdown.js
// ---------------------------------------------------------------------------
// Helpers around Qt's built-in markdown renderer (Text.MarkdownText).
//
// The rendering itself is entirely done by Qt. This module only takes care
// of three things around it:
//
//   1. Fast path detection - a plain title is rendered with Text.PlainText
//      so it never goes through the markdown parser at all.
//   2. Code blocks - Qt renders them as preformatted text that never wraps,
//      so a long line would be wider than the menu and would be cut off.
//      The blocks are therefore flattened into inline code lines that wrap
//      like normal text.
//   3. Link safety - only http:, https: and mailto: links are allowed,
//      everything else (javascript:, data:, file:, local paths) is turned
//      into plain text before Qt can turn it into a clickable anchor.
//
// Every regular expression below is linear: negated character classes only,
// no nested quantifiers and no back-references -> no ReDoS.
// ---------------------------------------------------------------------------

// --- Fast path detection ---------------------------------------------------
var INLINE_MARKER = /[#*_`~[\]|>]/;
var BLOCK_MARKER = /^[ \t]*(?:[-*+]|\d{1,9}[.)])[ \t]+/m;
var RULE_MARKER = /^[ \t]*-{3,}[ \t]*$/m;

// --- Link safety -----------------------------------------------------------
var ALLOWED_PROTOCOLS = ["https:", "http:", "mailto:"];
var LINK_PATTERN = /\[([^\]\n]*)\]\(((?:[^()\n]|\([^()\n]*\))*)\)/g;

// Decodes the small set of entities we can produce (plus numeric refs) so a
// URL can be validated on its effective value.
function decodeEntities(text) {
    return String(text)
        .replace(/&#x([0-9a-fA-F]{1,6});/g, function (m, hex) {
            return codePoint(parseInt(hex, 16));
        })
        .replace(/&#([0-9]{1,7});/g, function (m, dec) {
            return codePoint(parseInt(dec, 10));
        })
        .replace(/&quot;/g, "\"")
        .replace(/&apos;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&");
}

function codePoint(value) {
    if (!value || value < 32 || value > 0x10FFFF)
        return "";
    try {
        return String.fromCodePoint(value);
    } catch (e) {
        return "";
    }
}

// Returns true when the URL may be turned into a link.
function isSafeUrl(rawUrl) {
    if (rawUrl === null || rawUrl === undefined)
        return false;

    const decoded = decodeEntities(String(rawUrl)).trim();
    if (decoded === "")
        return false;

    // No control characters or whitespace - a classic obfuscation vector.
    if (/[\u0000-\u0020\u007f]/.test(decoded))
        return false;

    const colon = decoded.indexOf(":");
    if (colon < 0)
        return false; // relative or local path -> rejected

    const scheme = decoded.substring(0, colon + 1).toLowerCase();
    if (ALLOWED_PROTOCOLS.indexOf(scheme) < 0)
        return false;

    // The scheme must be followed by an actual target.
    return decoded.length > colon + 1;
}

// Replaces every link with a protocol that is not allowed by its plain text.
function sanitizeLinks(text) {
    return text.replace(LINK_PATTERN, function (match, label, url) {
        if (isSafeUrl(url))
            return match;
        return label;
    });
}

// --- Code blocks -----------------------------------------------------------

// Flattens a code block into inline code lines separated by hard line breaks.
function flattenCode(code) {
    const lines = code.replace(/\n+$/, "").split("\n");
    const rendered = [];
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].replace(/^[ \t]+/, "");
        const ticks = line.indexOf("`") >= 0 ? "``" : "`";
        const pad = ticks === "``" ? " " : "";
        // Two trailing spaces = hard line break (GFM).
        rendered.push(ticks + pad + line + pad + ticks + (i < lines.length - 1 ? "  " : ""));
    }
    return rendered.join("\n");
}

// Prepares a markdown source for Qt's markdown renderer.
function prepareForQt(source) {
    if (source === null || source === undefined)
        return "";

    let out = sanitizeLinks(String(source));

    // Fenced code blocks.
    out = out.replace(/```[^\n]*\n([\s\S]*?)```/g, function (match, code) {
        return flattenCode(code);
    });

    // Indented code blocks (4 spaces / tab).
    out = out.replace(/^(?: {4}|\t)(.*)$/gm, function (match, line) {
        if (line.trim() === "")
            return "";
        const ticks = line.indexOf("`") >= 0 ? "``" : "`";
        const pad = ticks === "``" ? " " : "";
        return ticks + pad + line.trim() + pad + ticks + "  ";
    });

    return out;
}

// --- Public API ------------------------------------------------------------

// True when the source contains anything that looks like markdown. Plain
// titles take the fast path and are rendered as Text.PlainText.
function hasMarkdown(source) {
    if (source === null || source === undefined)
        return false;
    const text = String(source);
    if (text === "")
        return false;
    if (INLINE_MARKER.test(text))
        return true;
    if (BLOCK_MARKER.test(text))
        return true;
    return RULE_MARKER.test(text);
}
