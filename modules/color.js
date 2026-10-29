// HSV/RGB plumbing for the Custom palette picker. Plain JS so
// `node --test tests/` can cover the conversion without a QML runtime;
// modules/ColorPicker.qml imports it as `Color`.

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function pad(value) {
    const text = Math.round(value).toString(16);
    return text.length < 2 ? "0" + text : text;
}

// h 0..360, s/v 0..1 -> [r, g, b] 0..255.
function hsvToRgb(h, s, v) {
    const hue = ((h % 360) + 360) % 360;
    const sat = clamp(s, 0, 1);
    const val = clamp(v, 0, 1);
    const c = val * sat;
    const x = c * (1 - Math.abs((hue / 60) % 2 - 1));
    const m = val - c;
    let rgb;
    if (hue < 60)
        rgb = [c, x, 0];
    else if (hue < 120)
        rgb = [x, c, 0];
    else if (hue < 180)
        rgb = [0, c, x];
    else if (hue < 240)
        rgb = [0, x, c];
    else if (hue < 300)
        rgb = [x, 0, c];
    else
        rgb = [c, 0, x];
    return rgb.map(channel => Math.round((channel + m) * 255));
}

// [r, g, b] 0..255 -> [h 0..360, s 0..1, v 0..1].
function rgbToHsv(r, g, b) {
    const red = clamp(r, 0, 255) / 255;
    const green = clamp(g, 0, 255) / 255;
    const blue = clamp(b, 0, 255) / 255;
    const max = Math.max(red, green, blue);
    const min = Math.min(red, green, blue);
    const delta = max - min;
    let hue = 0;
    if (delta > 0) {
        if (max === red)
            hue = 60 * (((green - blue) / delta) % 6);
        else if (max === green)
            hue = 60 * ((blue - red) / delta + 2);
        else
            hue = 60 * ((red - green) / delta + 4);
    }
    if (hue < 0)
        hue += 360;
    return [hue, max === 0 ? 0 : delta / max, max];
}

function rgbToHex(r, g, b) {
    return "#" + pad(clamp(r, 0, 255)) + pad(clamp(g, 0, 255)) + pad(clamp(b, 0, 255));
}

// "#rrggbb" -> [r, g, b], null for anything else.
function hexToRgb(hex) {
    if (typeof hex !== "string" || !/^#[0-9a-fA-F]{6}$/.test(hex))
        return null;
    return [
        parseInt(hex.slice(1, 3), 16),
        parseInt(hex.slice(3, 5), 16),
        parseInt(hex.slice(5, 7), 16)
    ];
}

function hsvToHex(h, s, v) {
    const rgb = hsvToRgb(h, s, v);
    return rgbToHex(rgb[0], rgb[1], rgb[2]);
}

if (typeof module !== "undefined")
    module.exports = { clamp, hsvToRgb, rgbToHsv, rgbToHex, hexToRgb, hsvToHex };
