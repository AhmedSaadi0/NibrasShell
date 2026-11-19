// utils/Markdown.js
// ---------------------------------------------------------------------------
// Helpers around Qt's built-in markdown renderer (Text.MarkdownText).
//
// The rendering itself is entirely done by Qt. This module only takes care
// of four things around it:
//
//   1. Fast path detection - a plain title is rendered with Text.PlainText
//      so it never goes through the markdown parser at all.
//   2. Code blocks - Qt renders them as preformatted text that never wraps,
//      so a long line would be wider than the menu and would be cut off.
//      The blocks are extracted before sanitizing and then flattened into
//      wrapping inline code lines.
//   3. Link safety - only http:, https: and mailto: links are allowed,
//      everything else (javascript:, data:, file:, local paths) is turned
//      into plain text before Qt can turn it into a clickable anchor.
//   4. Images - all markdown image syntax is stripped so Qt cannot fetch
//      local or external image resources from task content.
//
// Scanners are line-based rather than greedy so unclosed fences stay linear.
// ---------------------------------------------------------------------------

// --- Fast path detection ---------------------------------------------------
var INLINE_MARKER = /[#*_`~[\]|>]/;
var BLOCK_MARKER = /^[ \t]*(?:[-*+]|\d{1,9}[.)])[ \t]+/m;
var RULE_MARKER = /^[ \t]*-{3,}[ \t]*$/m;
var SETEXT_MARKER = /^[ \t]*={3,}[ \t]*$/m;

// --- Link safety -----------------------------------------------------------
var ALLOWED_PROTOCOLS = ["https:", "http:", "mailto:"];
var LINK_PATTERN = /\[([^\]\n]*)\]\(((?:[^()\n]|\([^()\n]*\))*)\)/g;
var IMAGE_PATTERN = /!\[([^\]\n]*)\]\(((?:[^()\n]|\([^()\n]*\))*)\)/g;
var REF_IMAGE_PATTERN = /!\[([^\]\n]*)\]\[([^\]\n]*)\]/g;
var SHORTCUT_IMAGE_PATTERN = /!\[([^\]\n]*)\]/g;
var AUTOLINK_PATTERN = /<([A-Za-z][A-Za-z0-9+.-]*:[^<>\n]*)>/g;
var REFERENCE_DEFINITION_PATTERN = /^([ \t]*)\[([^\]\n]+)\]:[ \t]*(.*)$/;

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

// Extracts the effective URL from an inline destination. Whitespace is only
// accepted before an optional title; whitespace inside the URL stays invalid.
function parseLinkDestination(rawDestination) {
    const text = decodeEntities(rawDestination).trim();
    if (text === "")
        return "";

    if (text.charAt(0) === "<") {
        const close = text.indexOf(">");
        if (close < 0)
            return "";
        return text.substring(1, close).trim();
    }

    const match = /^([^\s]+)(?:\s+.*)?$/.exec(text);
    return match ? match[1] : "";
}

// Returns true when the URL may be turned into a link.
function isSafeUrl(rawUrl) {
    if (rawUrl === null || rawUrl === undefined)
        return false;

    const decoded = parseLinkDestination(rawUrl);
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

// Images are always removed, even when the URL is "safe": task content must
// never trigger a local or external image fetch.
function sanitizeImages(text) {
    return text
        .replace(IMAGE_PATTERN, function (match, label) { return label; })
        .replace(REF_IMAGE_PATTERN, function (match, label) { return label; })
        .replace(SHORTCUT_IMAGE_PATTERN, function (match, label) { return label; });
}

// Neutralizes unsafe <scheme:...> autolinks without touching HTML-like tags.
function sanitizeAutolinks(text) {
    return text.replace(AUTOLINK_PATTERN, function (match, url) {
        if (isSafeUrl(url))
            return match;
        return "&lt;" + url + "&gt;";
    });
}

// Rewrites unsafe reference definitions without the "[id]:" prefix so MD4C
// cannot resolve a later [label][id] into a clickable link.
function sanitizeReferenceDefinitions(text) {
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const match = REFERENCE_DEFINITION_PATTERN.exec(lines[i]);
        if (!match)
            continue;
        const destination = parseLinkDestination(match[3]);
        if (isSafeUrl(destination))
            continue;
        lines[i] = match[1] + match[2] + ":" + (match[3] ? " " + match[3] : "");
    }
    return lines.join("\n");
}

// --- Code blocks -----------------------------------------------------------

var FENCE_OPEN_PATTERN = /^[ \t]*(`{3,}|~{3,})[^\n]*$/;
var FENCE_CLOSE_PATTERN = /^[ \t]*(`+|~+)[ \t]*$/;
// After the 4 spaces/tab, a list marker must not follow. This is a deliberate
// heuristic, not a full CommonMark parser.
var INDENTED_CODE_PATTERN = /^(?: {4}|\t)(?![ \t]*(?:[-*+]|\d{1,9}[.)])[ \t])/;

function isBlankLine(line) {
    return /^[ \t]*$/.test(line);
}

function isIndentedCodeLine(line) {
    return !isBlankLine(line) && INDENTED_CODE_PATTERN.test(line);
}

function makePlaceholderFactory(source) {
    let prefix = "MDBLOCKTOKEN";
    while (source.indexOf(prefix) >= 0)
        prefix += "X";
    let seq = 0;
    return function () {
        return prefix + (seq++) + "END";
    };
}

// Line-by-line extraction keeps unclosed fences strictly linear and leaves
// them as ordinary text (where sanitizing is the correct behavior).
function extractCodeBlocks(source) {
    const text = String(source);
    const lines = text.split("\n");
    const makeToken = makePlaceholderFactory(text);
    const blocks = [];
    const out = [];
    let i = 0;

    while (i < lines.length) {
        const opening = lines[i];
        const fence = FENCE_OPEN_PATTERN.exec(opening);

        if (fence) {
            const marker = fence[1];
            const fenceChar = marker.charAt(0);
            const fenceLength = marker.length;
            const codeLines = [];
            i++;

            let closed = false;
            while (i < lines.length) {
                const candidate = FENCE_CLOSE_PATTERN.exec(lines[i]);
                if (candidate && candidate[1].charAt(0) === fenceChar && candidate[1].length >= fenceLength) {
                    i++;
                    closed = true;
                    break;
                }
                codeLines.push(lines[i]);
                i++;
            }

            if (closed) {
                const token = makeToken();
                blocks.push({ token: token, code: codeLines.join("\n") });
                out.push(token);
            } else {
                out.push(opening);
                for (let j = 0; j < codeLines.length; j++)
                    out.push(codeLines[j]);
            }
            continue;
        }

        if (isIndentedCodeLine(lines[i])) {
            const codeLines = [];
            while (i < lines.length) {
                if (isIndentedCodeLine(lines[i])) {
                    codeLines.push(lines[i]);
                    i++;
                } else if (isBlankLine(lines[i]) && i + 1 < lines.length && isIndentedCodeLine(lines[i + 1])) {
                    codeLines.push(lines[i]);
                    i++;
                } else {
                    break;
                }
            }
            const token = makeToken();
            blocks.push({ token: token, code: codeLines.join("\n") });
            out.push(token);
            continue;
        }

        out.push(lines[i]);
        i++;
    }

    return { text: out.join("\n"), blocks: blocks };
}

function expandTabs(line, tabWidth) {
    let out = "";
    for (let i = 0; i < line.length; i++) {
        const ch = line.charAt(i);
        if (ch === "\t")
            out += " ".repeat(tabWidth - (out.length % tabWidth));
        else
            out += ch;
    }
    return out;
}

// One code line becomes one wrapping inline-code span. NBSP keeps leading
// indentation visible, and the fence grows past any backtick run in the line.
function formatCodeLine(line) {
    const expanded = expandTabs(line, 4);
    const leading = /^[ \t]*/.exec(expanded)[0];
    let content = "\u00A0".repeat(leading.length) + expanded.substring(leading.length);

    const runs = content.match(/`+/g) || [];
    let maxRun = 0;
    for (let i = 0; i < runs.length; i++)
        maxRun = Math.max(maxRun, runs[i].length);
    const fence = "`".repeat(maxRun + 1);

    if (content.charAt(0) === "`")
        content = " " + content;
    if (content.charAt(content.length - 1) === "`")
        content += " ";

    return fence + content + fence;
}

// Flattens a code block into inline code lines separated by hard line breaks.
function flattenCode(code) {
    const lines = code.replace(/\n+$/, "").split("\n");
    const rendered = [];
    for (let i = 0; i < lines.length; i++) {
        rendered.push(formatCodeLine(lines[i]) + (i < lines.length - 1 ? "  " : ""));
    }
    return rendered.join("\n");
}

function restoreCodeBlocks(text, blocks) {
    let out = text;
    for (let i = 0; i < blocks.length; i++)
        out = out.split(blocks[i].token).join(flattenCode(blocks[i].code));
    return out;
}

// Prepares a markdown source for Qt's markdown renderer.
function prepareForQt(source) {
    if (source === null || source === undefined)
        return "";

    const extracted = extractCodeBlocks(String(source));
    let out = sanitizeImages(extracted.text);
    out = sanitizeLinks(out);
    out = sanitizeReferenceDefinitions(out);
    out = sanitizeAutolinks(out);
    return restoreCodeBlocks(out, extracted.blocks);
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
    if (RULE_MARKER.test(text))
        return true;
    return SETEXT_MARKER.test(text);
}
