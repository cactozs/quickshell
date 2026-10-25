// Launcher arithmetic parser; kept in plain JS so it can be tested with
// node --test without a QML runtime. Nested helpers keep the parser
// state (s, pos) local.
// Arithmetic over the whole query; "" unless it parses as an expression
// (needs a digit and, without a leading "=", an operator). `x%` is a
// percent, `x % y` a remainder -- the difference is whether a factor
// follows. Trigonometry works in degrees (sin(30) = 0.5); constants,
// variables and units are not supported.
function calculate(raw) {
    // Typographic operators and the comma decimal separator are free.
    let s = raw.trim().toLowerCase().replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
    const forced = s.startsWith("=");
    if (forced)
        s = s.slice(1).trim();
    if (s === "" || !/[0-9]/.test(s) || !forced && !/[+\-*/%^(]/.test(s))
        return "";

    const functions = {
        sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, exp: Math.exp,
        ln: Math.log, log: Math.log10, log2: Math.log2,
        round: Math.round, floor: Math.floor, ceil: Math.ceil,
        sin: x => Math.sin(x * Math.PI / 180), cos: x => Math.cos(x * Math.PI / 180),
        tan: x => Math.tan(x * Math.PI / 180), asin: x => Math.asin(x) * 180 / Math.PI,
        acos: x => Math.acos(x) * 180 / Math.PI, atan: x => Math.atan(x) * 180 / Math.PI
    };

    let pos = 0;

    function skip() {
        while (s.charAt(pos) === " ")
            pos++;
    }

    // A factor starts with a digit, a point, a bracket or a function name.
    function startsFactor() {
        return /[0-9.a-z(]/.test(s.charAt(pos));
    }

    function primary() {
        skip();
        const c = s.charAt(pos);
        if (c === "(") {
            pos++;
            const v = expression();
            skip();
            if (s.charAt(pos) !== ")")
                return NaN;
            pos++;
            return v;
        }
        const name = /^[a-z]+/.exec(s.slice(pos));
        if (name) {
            const fn = functions[name[0]];
            pos += name[0].length;
            skip();
            if (!fn || s.charAt(pos) !== "(")
                return NaN;
            pos++;
            const v = expression();
            skip();
            if (s.charAt(pos) !== ")")
                return NaN;
            pos++;
            return fn(v);
        }
        const number = /^[0-9]*\.?[0-9]+/.exec(s.slice(pos));
        if (!number)
            return NaN;
        pos += number[0].length;
        return Number(number[0]);
    }

    function postfix() {
        let v = primary();
        for (;;) {
            skip();
            if (s.charAt(pos) !== "%")
                return v;
            pos++;
            skip();
            if (startsFactor())
                return v % unary();
            v /= 100;
        }
    }

    function power() {
        const base = postfix();
        skip();
        if (s.charAt(pos) !== "^")
            return base;
        pos++;
        return Math.pow(base, unary());
    }

    function unary() {
        skip();
        const c = s.charAt(pos);
        if (c === "-" || c === "+") {
            pos++;
            return c === "-" ? -unary() : unary();
        }
        return power();
    }

    function term() {
        let v = unary();
        for (;;) {
            skip();
            const c = s.charAt(pos);
            if (c !== "*" && c !== "/")
                return v;
            pos++;
            const r = unary();
            v = c === "*" ? v * r : v / r;
        }
    }

    function expression() {
        let v = term();
        for (;;) {
            skip();
            const c = s.charAt(pos);
            if (c !== "+" && c !== "-")
                return v;
            pos++;
            const r = term();
            v = c === "+" ? v + r : v - r;
        }
    }

    const value = expression();
    skip();
    if (pos !== s.length || !Number.isFinite(value))
        return "";
    return String(parseFloat(value.toPrecision(12)));
}

if (typeof module !== "undefined")
    module.exports = { calculate };
