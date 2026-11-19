// Node/vm regression tests for utils/Markdown.js.
// Run: node tests/test_markdown.js

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const NBSP = "\u00A0";
const sourcePath = path.join(__dirname, "..", "utils", "Markdown.js");
const source = fs.readFileSync(sourcePath, "utf8");

const context = {};
vm.createContext(context);
vm.runInContext(
    source + "\n;globalThis.__md = { hasMarkdown, prepareForQt, flattenCode, isSafeUrl };",
    context
);
const Markdown = context.__md;

let passed = 0;
let failed = 0;

function test(name, fn) {
    try {
        fn();
        passed++;
        console.log("PASS " + name);
    } catch (error) {
        failed++;
        console.error("FAIL " + name);
        console.error("  " + (error && error.message ? error.message : error));
    }
}

test("hasMarkdown recognizes Setext === headings", () => {
    assert.equal(Markdown.hasMarkdown("Title\n==="), true);
    assert.equal(Markdown.hasMarkdown("plain title"), false);
});

test("fenced code is protected from sanitizeLinks", () => {
    const out = Markdown.prepareForQt("Before\n\n```js\nconst a = arr[i](x);\n```\n");
    assert.equal(out.includes("`const a = arr[i](x);`"), true);
    assert.doesNotMatch(out, /arri/);
});

test("fenced code keeps unsafe-looking link text", () => {
    const out = Markdown.prepareForQt("```\n[x](javascript:alert(1))\n```");
    assert.equal(out.includes("`[x](javascript:alert(1))`"), true);
});

test("titled and angle-bracketed destinations stay safe", () => {
    assert.equal(Markdown.isSafeUrl('https://example.com "title"'), true);
    assert.equal(Markdown.isSafeUrl("<https://example.com>"), true);
    assert.equal(Markdown.isSafeUrl("<https://example.com> 'title'"), true);

    const a = Markdown.prepareForQt('[label](https://example.com "title")');
    const b = Markdown.prepareForQt("[label](<https://example.com>)");
    const c = Markdown.prepareForQt("[label](<https://example.com> \"title\")");
    assert.equal(a, '[label](https://example.com "title")');
    assert.equal(b, "[label](<https://example.com>)");
    assert.equal(c, '[label](<https://example.com> "title")');
});

test("unsafe and relative inline links are neutralized", () => {
    assert.equal(Markdown.prepareForQt("[label](javascript:alert(1))"), "label");
    assert.equal(Markdown.prepareForQt("[label](data:text/html,x)"), "label");
    assert.equal(Markdown.prepareForQt("[label](/etc/passwd)"), "label");
});

test("autolinks are sanitized by scheme", () => {
    assert.equal(
        Markdown.prepareForQt("<javascript:alert(1)>"),
        "&lt;javascript:alert(1)&gt;"
    );
    assert.equal(Markdown.prepareForQt("<https://example.com>"), "<https://example.com>");
});

test("unsafe reference definitions lose [id]: syntax", () => {
    const out = Markdown.prepareForQt("[label][id]\n\n[id]: javascript:alert(1)");
    assert.doesNotMatch(out, /\[id\]:/);
    assert.match(out, /^id: javascript:alert\(1\)$/m);
});

test("all markdown image forms are stripped", () => {
    assert.equal(Markdown.prepareForQt("![alt](https://example.com/x.png)"), "alt");
    assert.equal(Markdown.prepareForQt("![alt][id]"), "alt");
    assert.equal(Markdown.prepareForQt("![alt]"), "alt");
});

test("flattenCode preserves indentation with NBSP", () => {
    const out = Markdown.flattenCode("\tfoo\n  bar");
    assert.equal(out, "`" + NBSP.repeat(4) + "foo`" + "  \n`" + NBSP.repeat(2) + "bar`");
});

test("flattenCode grows fences past the longest backtick run", () => {
    assert.equal(Markdown.flattenCode("use `` here"), "```use `` here```");
    assert.equal(Markdown.flattenCode("```"), "```` ``` ````");
});

test("flattenCode pads content that starts or ends with a backtick", () => {
    assert.equal(Markdown.flattenCode("`code`"), "`` `code` ``");
});

test("nested list lines are not flattened as indented code", () => {
    const input = "    - item\n    1. first";
    assert.equal(Markdown.prepareForQt(input), input);
});

test("real indented code is flattened with NBSP indentation", () => {
    const out = Markdown.prepareForQt("    let x = 1;");
    assert.equal(out, "`" + NBSP.repeat(4) + "let x = 1;`");
});

test("unclosed fences leave no placeholder behind", () => {
    const out = Markdown.prepareForQt("```js\narr[i](x)\n");
    assert.doesNotMatch(out, /MDBLOCKTOKEN/);
});

console.log("");
console.log("Markdown tests: " + passed + " passed, " + failed + " failed");
process.exitCode = failed === 0 ? 0 : 1;
