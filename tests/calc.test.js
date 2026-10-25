// Pure-logic tests for modules/calc.js; run with `node --test tests/`.
const test = require("node:test");
const assert = require("node:assert");
const { calculate } = require("../modules/calc.js");

test("plain arithmetic", () => {
    assert.equal(calculate("2+2"), "4");
    assert.equal(calculate("8/2*2"), "8");
    assert.equal(calculate("2-3-4"), "-5");
    assert.equal(calculate("2^3^2"), "512"); // right-associative
});

test("forced expression and the comma decimal", () => {
    assert.equal(calculate("=2+2"), "4");
    assert.equal(calculate("1,5+2"), "3.5");
});

test("percent versus remainder", () => {
    assert.equal(calculate("50%"), "0.5");
    assert.equal(calculate("5%2"), "1");
});

test("functions work in degrees", () => {
    assert.equal(calculate("sin(30)"), "0.5");
    assert.equal(calculate("sqrt(9)+1"), "4");
});

test("non-expressions and non-finite results are empty", () => {
    assert.equal(calculate("hello"), "");
    assert.equal(calculate("1/0"), "");
    assert.equal(calculate("2+"), "");
    assert.equal(calculate("(2+3"), "");
});
