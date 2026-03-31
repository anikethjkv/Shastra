/* ═══════════════════════════════════════════════════════════════
   Shastra EV Dashboard — Canvas Gauge Renderers (Optimised for Pi)
   ═══════════════════════════════════════════════════════════════ */

const Gauges = (() => {

    const BEND_TILT_X = 62;
    const BEND_RADIUS = 35;
    const BASE_TOP_BAR_EXTEND = 42;

    /* ── Colour palette ──────────────────────────── */
    const C = {
        track: '#e2e5ea',
        text: '#1a1d23',
        dim: '#9ca3af',
        green: '#2e7d32',
        teal: '#00897b',
        cyan: '#00acc1',
        amber: '#f57f17',
        red: '#d32f2f',
    };

    /* ── Cached Offscreen Backgrounds ────────────── */
    const cache = {
        rpmBg: null,
        rpmBgKey: '',
    };




    function createRPMBackground(W, H, r, cx, cy, maxRPM, topBarExtend) {
        const c = document.createElement('canvas');
        c.width = W; c.height = H;
        const ctx = c.getContext('2d');

        const trackWidth = 32;
        const xStart = cx - r;
        const yStart = cy;
        const tiltX = BEND_TILT_X;
        const radius = BEND_RADIUS;
        const xEnd = cx + r + topBarExtend;
        const topY = yStart - r;

        const angle = Math.atan2(r, tiltX);
        const tangentD = radius / Math.tan(angle / 2);
        const tx = xStart - (tangentD * (tiltX / Math.sqrt(tiltX * tiltX + r * r)));
        const ty = topY + (tangentD * (r / Math.sqrt(tiltX * tiltX + r * r)));

        const sweep = Math.PI/2 - (Math.PI/2 - Math.atan(tiltX/r));
        const arcStart = Math.atan2(ty - (topY + radius), tx - xStart);

        const d_slant = Math.sqrt(Math.pow(tx - (xStart - tiltX), 2) + Math.pow(ty - yStart, 2));
        const d_arc = radius * sweep;
        const d_flat = xEnd - (xStart + radius);
        const totalLen = d_slant + d_arc + d_flat;

        function getPoint(dist) {
            if (dist <= d_slant) {
                const p = dist / d_slant;
                return { x: (xStart - tiltX) + p * (tx - (xStart - tiltX)), y: yStart + p * (ty - yStart), angle: Math.atan2(ty - yStart, tx - (xStart - tiltX)) };
            } else if (dist <= d_slant + d_arc) {
                const p = (dist - d_slant) / d_arc;
                const cA = arcStart + p * sweep;
                return { x: xStart + radius * Math.cos(cA), y: topY + radius + radius * Math.sin(cA), angle: cA + Math.PI/2 };
            } else {
                const p = (dist - d_slant - d_arc) / d_flat;
                return { x: xStart + radius + p * d_flat, y: topY, angle: 0 };
            }
        }

        /* 1. Dark Grey Border */
        ctx.strokeStyle = '#374151';
        ctx.lineWidth = trackWidth + 4;
        ctx.lineCap = 'butt';
        ctx.lineJoin = 'round';
        ctx.beginPath();
        ctx.moveTo(xStart - tiltX, yStart);
        ctx.lineTo(tx, ty);
        ctx.arcTo(xStart, topY, xStart + radius, topY, radius);
        ctx.lineTo(xEnd, topY);
        ctx.stroke();

        /* 2. Inner Track Base */
        ctx.strokeStyle = C.track;
        ctx.lineWidth = trackWidth;
        ctx.stroke();

        /* 2b. End-cap borders */
        const startAngle = Math.atan2(ty - yStart, tx - (xStart - tiltX));
        const capHalf = (trackWidth + 4) / 2;
        const sx = xStart - tiltX;
        const sy = yStart;
        const ex = xEnd;
        const ey = topY;

        ctx.strokeStyle = '#374151';
        ctx.lineWidth = 2;

        ctx.beginPath();
        ctx.moveTo(sx + Math.cos(startAngle + Math.PI / 2) * capHalf, sy + Math.sin(startAngle + Math.PI / 2) * capHalf);
        ctx.lineTo(sx + Math.cos(startAngle - Math.PI / 2) * capHalf, sy + Math.sin(startAngle - Math.PI / 2) * capHalf);
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(ex, ey - capHalf);
        ctx.lineTo(ex, ey + capHalf);
        ctx.stroke();

        /* 3. SEGMENTATION (NO MIDDLE LINE) */
        ctx.strokeStyle = '#ffffff';
        ctx.lineWidth = 1.5;
        ctx.globalAlpha = 0;
        const segments = 100;
        for (let i = 1; i < segments; i++) {
            const pt = getPoint((i / segments) * totalLen);
            ctx.save();
            ctx.translate(pt.x, pt.y);
            ctx.rotate(pt.angle + Math.PI/2);
            ctx.beginPath();
            ctx.moveTo(0, -trackWidth/2 + 0.5);
            ctx.lineTo(0, trackWidth/2 - 0.5);
            ctx.stroke();
            ctx.restore();
        }
        ctx.globalAlpha = 1;

        /* Ticks and Labels */
        ctx.fillStyle = C.dim;
        ctx.font = '700 14px Inter, sans-serif';
        ctx.textAlign = 'center';
        for (let i = 0; i <= 5; i++) {
            const val = i * 1000;
            const pt = getPoint((val / maxRPM) * totalLen);
            let lx = pt.x, ly = pt.y;
            if (val / maxRPM <= 0.3) lx -= 45; else ly -= 25;
            lx = Math.max(34, Math.min(W - 34, lx));
            ly = Math.max(24, Math.min(H - 12, ly));
            ctx.fillText(val, lx, ly);
        }
        return c;
    }

    /* ────────────────────────────────────────────────────────────
       RPM Gauge
    ──────────────────────────────────────────────────────────── */
    function drawRPMGauge(canvas, rpm, speed, maxRPM = 5000) {
        const ctx = canvas.getContext('2d');
        const W = canvas.width;
        const H = canvas.height;
        ctx.clearRect(0, 0, W, H);

        const cx = (W / 2) - 26;
        const trackWidth = 32;
        const cy = H * 0.85;
        const outerPad = ((trackWidth + 4) / 2) + 16;
        const desiredR = Math.min(W * 0.38, H * 0.68);
        const r = Math.max(
            120,
            Math.min(
                desiredR,
                cy - outerPad,
                cx - BEND_TILT_X - outerPad,
                W - cx - BASE_TOP_BAR_EXTEND - outerPad - 10,
            ),
        );

        const topBarExtend = Math.max(
            BASE_TOP_BAR_EXTEND,
            Math.min(100, W - (cx + r) - outerPad - 4),
        );

        const bgKey = `${W}x${H}|${Math.round(cx * 100) / 100}|${Math.round(r * 100) / 100}|${Math.round(cy * 100) / 100}|${trackWidth}|${Math.round(topBarExtend * 100) / 100}|${maxRPM}`;
        if (!cache.rpmBg || cache.rpmBgKey !== bgKey) {
            cache.rpmBg = createRPMBackground(W, H, r, cx, cy, maxRPM, topBarExtend);
            cache.rpmBgKey = bgKey;
        }
        ctx.drawImage(cache.rpmBg, 0, 0);

        const pct = Math.min(rpm / maxRPM, 1);
        if (pct > 0) {
            const xOffset = cx - r;
            const yOffset = cy;
            const topY = yOffset - r;
            const tiltX = BEND_TILT_X;
            const radius = BEND_RADIUS;
            const xEnd = cx + r + topBarExtend;

            const angle = Math.atan2(r, tiltX);
            const tangentD = radius / Math.tan(angle / 2);
            const tx = xOffset - (tangentD * (tiltX / Math.sqrt(tiltX * tiltX + r * r)));
            const ty = topY + (tangentD * (r / Math.sqrt(tiltX * tiltX + r * r)));
            const arcStart = Math.atan2(ty - (topY + radius), tx - xOffset);
            const arcSweep = Math.PI - angle;

            /* Correct total path length: actual arc sweep = π - angle (NOT atan(tiltX/r)) */
            const d_slant = Math.sqrt(Math.pow(tx - (xOffset - tiltX), 2) + Math.pow(ty - yOffset, 2));
            const d_arc   = radius * (Math.PI - angle);
            const d_flat  = xEnd - (xOffset + tangentD);
            const totalLen = d_slant + d_arc + d_flat;
            const dFill = pct * totalLen;

            /* Single solid color interpolated from pct: teal → green → yellow → orange → red */
            let fillColor;
            if (pct <= 0.25) {
                const k = pct / 0.25;
                const rv = Math.round(0   + (67  - 0)   * k);
                const gv = Math.round(150 + (160 - 150) * k);
                const bv = Math.round(136 + (71  - 136) * k);
                fillColor = `rgb(${rv},${gv},${bv})`;
            } else if (pct <= 0.5) {
                const k = (pct - 0.25) / 0.25;
                const rv = Math.round(67  + (255 - 67)  * k);
                const gv = Math.round(160 + (214 - 160) * k);
                const bv = Math.round(71  + (10  - 71)  * k);
                fillColor = `rgb(${rv},${gv},${bv})`;
            } else if (pct <= 0.75) {
                const k = (pct - 0.5) / 0.25;
                const rv = Math.round(255 + (255 - 255) * k);
                const gv = Math.round(214 + (152 - 214) * k);
                const bv = Math.round(10  + (0   - 10)  * k);
                fillColor = `rgb(${rv},${gv},${bv})`;
            } else {
                const k = (pct - 0.75) / 0.25;
                const rv = Math.round(255 + (225 - 255) * k);
                const gv = Math.round(152 + (60  - 152) * k);
                const bv = Math.round(0   + (60  - 0)   * k);
                fillColor = `rgb(${rv},${gv},${bv})`;
            }

            /* Draw fill using setLineDash on the EXACT same arcTo path as the background.
               This guarantees the fill follows the track without any geometry mismatch. */
            ctx.strokeStyle = fillColor;
            ctx.lineWidth = trackWidth;
            ctx.lineCap = 'butt';
            ctx.lineJoin = 'round';
            ctx.setLineDash([dFill, totalLen * 2 + 100]);
            ctx.lineDashOffset = 0;
            ctx.beginPath();
            ctx.moveTo(xOffset - tiltX, yOffset);
            ctx.lineTo(tx, ty);
            ctx.arcTo(xOffset, topY, xOffset + radius, topY, radius);
            ctx.lineTo(xEnd, topY);
            ctx.stroke();
            ctx.setLineDash([]);

            /* Border caps on both ends of active fill */
            const startAngle = Math.atan2(ty - yOffset, tx - (xOffset - tiltX));
            const capHalf = trackWidth / 2;
            function pointOnPath(dist) {
                if (dist <= d_slant) {
                    const p = d_slant > 0 ? (dist / d_slant) : 0;
                    return {
                        x: (xOffset - tiltX) + p * (tx - (xOffset - tiltX)),
                        y: yOffset + p * (ty - yOffset),
                        a: startAngle,
                    };
                }
                if (dist <= d_slant + d_arc) {
                    const p = d_arc > 0 ? ((dist - d_slant) / d_arc) : 0;
                    const ca = arcStart + p * arcSweep;
                    return {
                        x: xOffset + radius * Math.cos(ca),
                        y: topY + radius + radius * Math.sin(ca),
                        a: ca + Math.PI / 2,
                    };
                }
                const p = d_flat > 0 ? ((dist - d_slant - d_arc) / d_flat) : 1;
                return {
                    x: (xOffset + tangentD) + p * d_flat,
                    y: topY,
                    a: 0,
                };
            }

            const p0 = pointOnPath(0);
            ctx.strokeStyle = '#374151';
            ctx.lineWidth = 2;

            ctx.beginPath();
            ctx.moveTo(p0.x + Math.cos(p0.a + Math.PI / 2) * capHalf, p0.y + Math.sin(p0.a + Math.PI / 2) * capHalf);
            ctx.lineTo(p0.x + Math.cos(p0.a - Math.PI / 2) * capHalf, p0.y + Math.sin(p0.a - Math.PI / 2) * capHalf);
            ctx.stroke();
        }

        /* Readouts */
        ctx.fillStyle = C.text;
        const spd = Math.max(0, Math.round(speed));
        const spdStr = String(spd);
        const spdFont = spdStr.length >= 3 ? 96 : 110;
        const readoutX = cx + 14;
        const readoutY = cy - r / 2 + 52;
        ctx.font = `900 ${spdFont}px Inter, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'alphabetic';
        ctx.fillText(spdStr, readoutX, readoutY);
        ctx.font = '800 24px Inter, sans-serif';
        ctx.fillStyle = C.dim;
        ctx.fillText('KM/H', readoutX, readoutY + 40);
        ctx.font = '700 18px Inter, sans-serif';
        ctx.fillText(Math.round(rpm) + ' RPM', readoutX, readoutY - 90);
    }

    /* ────────────────────────────────────────────────────────────
       Tilt Indicator (Cheap to draw, no background needed)
    ──────────────────────────────────────────────────────────── */
    function drawTilt(canvas, ax, ay) {
        const ctx = canvas.getContext('2d');
        const W = canvas.width;
        const H = canvas.height;
        ctx.clearRect(0, 0, W, H);

        const cx = W / 2;
        const cy = H / 2;
        const r = Math.min(W, H) / 2 - 4;

        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.strokeStyle = C.track;
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.5, 0, Math.PI * 2);
        ctx.strokeStyle = C.track;
        ctx.lineWidth = 1;
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(cx - r, cy);
        ctx.lineTo(cx + r, cy);
        ctx.moveTo(cx, cy - r);
        ctx.lineTo(cx, cy + r);
        ctx.strokeStyle = '#d1d5db';
        ctx.lineWidth = 1;
        ctx.stroke();

        const maxG = 10;
        let dx = (ax / maxG) * r * 0.8;
        let dy = (ay / maxG) * r * 0.8;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > r * 0.9) {
            const s = (r * 0.9) / dist;
            dx *= s;
            dy *= s;
        }

        ctx.beginPath();
        ctx.arc(cx + dx, cy + dy, 6, 0, Math.PI * 2);
        ctx.fillStyle = C.cyan;
        ctx.fill();
        ctx.beginPath();
        ctx.arc(cx + dx, cy + dy, 6, 0, Math.PI * 2);
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 1.5;
        ctx.stroke();
    }

    // Expose clear cache method if window resizes
    function clearCache() {
        cache.speedBg = null;
        cache.rpmBg = null;
    }

    window.addEventListener('resize', clearCache);

    return { drawRPMGauge, drawTilt, clearCache };
})();
