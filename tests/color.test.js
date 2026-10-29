// Pure-logic tests for modules/color.js; run with `node --test tests/`.
const test = require("node:test");
const assert = require("node:assert");
const Color = require("../modules/color.js");

test("HSV primaries and greys", () => {
    assert.deepEqual(Color.hsvToRgb(0, 1, 1), [255, 0, 0]);
    assert.deepEqual(Color.hsvToRgb(120, 1, 1), [0, 255, 0]);
    assert.deepEqual(Color.hsvToRgb(240, 1, 1), [0, 0, 255]);
    assert.deepEqual(Color.hsvToRgb(0, 0, 0), [0, 0, 0]);
    assert.deepEqual(Color.hsvToRgb(0, 0, 1), [255, 255, 255]);
});

test("RGB to HSV and back", () => {
    assert.deepEqual(Color.rgbToHsv(255, 0, 0), [0, 1, 1]);
    assert.deepEqual(Color.rgbToHsv(0, 255, 0), [120, 1, 1]);
    assert.deepEqual(Color.rgbToHsv(0, 0, 255), [240, 1, 1]);
    assert.deepEqual(Color.rgbToHsv(128, 128, 128), [0, 0, 128 / 255]);

    for (const rgb of [[12, 200, 99], [255, 255, 0], [30, 30, 30], [200, 10, 240]]) {
        const hsv = Color.rgbToHsv(rgb[0], rgb[1], rgb[2]);
        assert.deepEqual(Color.hsvToRgb(hsv[0], hsv[1], hsv[2]), rgb);
    }
});

test("hex helpers", () => {
    assert.equal(Color.rgbToHex(255, 0, 0), "#ff0000");
    assert.equal(Color.hsvToHex(0, 1, 1), "#ff0000");
    assert.deepEqual(Color.hexToRgb("#12ab34"), [18, 171, 52]);
    assert.equal(Color.hexToRgb("12ab34"), null);
    assert.equal(Color.hexToRgb("#abc"), null);
});

test("out-of-range values clamp", () => {
    assert.deepEqual(Color.hsvToRgb(-60, 1, 1), [255, 0, 255]);
    assert.deepEqual(Color.hsvToRgb(0, 2, 2), [255, 0, 0]);
    assert.equal(Color.rgbToHex(-10, 300, 0), "#00ff00");
});
