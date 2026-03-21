/* ═══════════════════════════════════════════════════════════════
   Shastra EV Dashboard — Canvas Gauge Renderers (Optimised for Pi)
   ═══════════════════════════════════════════════════════════════ */

const Gauges = (() => {

    /* ── Colour palette ──────────────────────────── */
    const C = {
        track:   '#e2e5ea',
        text:    '#1a1d23',
        dim:     '#9ca3af',
        green:   '#2e7d32',
        teal:    '#00897b',
        cyan:    '#00acc1',
        amber:   '#f57f17',
        red:     '#d32f2f',
    };

    /* ── Cached Offscreen Backgrounds ────────────── */
    const cache = {
        speedBg: null,
        rpmBg: null,
        speedGrad: null,
    };

    function createSpeedBackground(W, H, r, cx, cy, startAngle, endAngle, totalArc, maxSpeed) {
        const c = document.createElement('canvas');
        c.width = W; c.height = H;
        const ctx = c.getContext('2d');

        /* Track */
        ctx.beginPath();
        ctx.arc(cx, cy, r, startAngle, endAngle);
        ctx.strokeStyle = C.track;
        ctx.lineWidth = 14;
        ctx.lineCap = 'round';
        ctx.stroke();

        /* Tick marks */
        const numTicks = 6;
        for (let i = 0; i <= numTicks; i++) {
            const angle = startAngle + (i / numTicks) * totalArc;
            const val = Math.round((i / numTicks) * maxSpeed);
            const tickInner = r - 22;
            const tickOuter = r - 10;
            const labelR = r - 32;

            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(angle) * tickInner, cy + Math.sin(angle) * tickInner);
            ctx.lineTo(cx + Math.cos(angle) * tickOuter, cy + Math.sin(angle) * tickOuter);
            ctx.strokeStyle = C.dim;
            ctx.lineWidth = 1.5;
            ctx.lineCap = 'butt';
            ctx.stroke();

            ctx.fillStyle = C.dim;
            ctx.font = '600 9px Inter, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(val, cx + Math.cos(angle) * labelR, cy + Math.sin(angle) * labelR);
        }
        return c;
    }

    /* ────────────────────────────────────────────────────────────
       Speed Gauge
    ──────────────────────────────────────────────────────────── */
    function drawSpeedometer(canvas, speed, maxSpeed = 60) {
        const ctx = canvas.getContext('2d');
        const W = canvas.width;
        const H = canvas.height;
        ctx.clearRect(0, 0, W, H);

        const cx = W / 2;
        const cy = H * 0.62;
        const r = Math.min(W, H) * 0.42;

        const startAngle = Math.PI * 0.8;
        const endAngle = Math.PI * 2.2;
        const totalArc = endAngle - startAngle;
        const valueAngle = startAngle + (Math.min(speed, maxSpeed) / maxSpeed) * totalArc;

        /* Create cache once */
        if (!cache.speedBg) {
            cache.speedBg = createSpeedBackground(W, H, r, cx, cy, startAngle, endAngle, totalArc, maxSpeed);
            cache.speedGrad = ctx.createLinearGradient(cx - r, cy, cx + r, cy);
            cache.speedGrad.addColorStop(0, C.cyan);
            cache.speedGrad.addColorStop(0.5, C.teal);
            cache.speedGrad.addColorStop(0.8, C.amber);
            cache.speedGrad.addColorStop(1, C.red);
        }

        /* Draw static background from cache (incredibly fast) */
        ctx.drawImage(cache.speedBg, 0, 0);

        /* Value arc */
        if (speed > 0) {
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, valueAngle);
            ctx.strokeStyle = cache.speedGrad;
            ctx.lineWidth = 14;
            ctx.lineCap = 'round';
            ctx.stroke();
        }

        /* Needle */
        const needleLen = r - 18;
        const nx = cx + Math.cos(valueAngle) * needleLen;
        const ny = cy + Math.sin(valueAngle) * needleLen;
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(nx, ny);
        ctx.strokeStyle = C.text;
        ctx.lineWidth = 2.5;
        ctx.lineCap = 'round';
        ctx.stroke();

        /* Center dot */
        ctx.beginPath();
        ctx.arc(cx, cy, 5, 0, Math.PI * 2);
        ctx.fillStyle = C.teal;
        ctx.fill();
    }


    function createRPMBackground(W, H, r, cx, cy, startAngle, endAngle, totalArc, maxRPM) {
        const c = document.createElement('canvas');
        c.width = W; c.height = H;
        const ctx = c.getContext('2d');

        /* Zone backgrounds */
        const zones = [
            { from: 0, to: 0.6, color: '#c8e6c9' },
            { from: 0.6, to: 0.8, color: '#fff9c4' },
            { from: 0.8, to: 1.0, color: '#ffcdd2' },
        ];

        zones.forEach(z => {
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle + z.from * totalArc, startAngle + z.to * totalArc);
            ctx.strokeStyle = z.color;
            ctx.lineWidth = 12;
            ctx.lineCap = 'butt';
            ctx.stroke();
        });

        /* Tick marks */
        const tickCount = 5;
        for (let i = 0; i <= tickCount; i++) {
            const angle = startAngle + (i / tickCount) * totalArc;
            const val = Math.round((i / tickCount) * maxRPM);
            const ti = r - 20;
            const to = r - 9;
            const lr = r - 30;

            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(angle) * ti, cy + Math.sin(angle) * ti);
            ctx.lineTo(cx + Math.cos(angle) * to, cy + Math.sin(angle) * to);
            ctx.strokeStyle = C.dim;
            ctx.lineWidth = 1.5;
            ctx.lineCap = 'butt';
            ctx.stroke();

            ctx.fillStyle = C.dim;
            ctx.font = '600 8px Inter, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(val, cx + Math.cos(angle) * lr, cy + Math.sin(angle) * lr);
        }
        return c;
    }

    /* ────────────────────────────────────────────────────────────
       RPM Gauge
    ──────────────────────────────────────────────────────────── */
    function drawRPMGauge(canvas, rpm, maxRPM = 5000) {
        const ctx = canvas.getContext('2d');
        const W = canvas.width;
        const H = canvas.height;
        ctx.clearRect(0, 0, W, H);

        const cx = W / 2;
        const cy = H * 0.65;
        const r = Math.min(W, H) * 0.44;

        const startAngle = Math.PI * 0.8;
        const endAngle = Math.PI * 2.2;
        const totalArc = endAngle - startAngle;
        const valueAngle = startAngle + (Math.min(rpm, maxRPM) / maxRPM) * totalArc;

        if (!cache.rpmBg) {
            cache.rpmBg = createRPMBackground(W, H, r, cx, cy, startAngle, endAngle, totalArc, maxRPM);
        }

        /* Draw static background */
        ctx.drawImage(cache.rpmBg, 0, 0);

        /* Value arc */
        if (rpm > 0) {
            const pct = rpm / maxRPM;
            let arcColor = C.green;
            if (pct > 0.8) arcColor = C.red;
            else if (pct > 0.6) arcColor = C.amber;

            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, valueAngle);
            ctx.strokeStyle = arcColor;
            ctx.lineWidth = 12;
            ctx.lineCap = 'round';
            ctx.stroke();
        }

        /* Needle */
        const needleLen = r - 16;
        const nx = cx + Math.cos(valueAngle) * needleLen;
        const ny = cy + Math.sin(valueAngle) * needleLen;
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(nx, ny);
        ctx.strokeStyle = C.text;
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(cx, cy, 4, 0, Math.PI * 2);
        ctx.fillStyle = C.green;
        ctx.fill();
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

    return { drawSpeedometer, drawRPMGauge, drawTilt, clearCache };
})();
