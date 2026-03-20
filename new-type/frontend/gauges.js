/* ═══════════════════════════════════════════════════════════════
   Shastra EV Dashboard — Canvas Gauge Renderers
   ═══════════════════════════════════════════════════════════════ */

const Gauges = (() => {

    /* ── Colour palette (light mode) ──────────────────────────── */
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

    /* ────────────────────────────────────────────────────────────
       Speed Gauge
       Large 220° arc with gradient fill: teal → cyan → amber → red
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

        /* Track */
        ctx.beginPath();
        ctx.arc(cx, cy, r, startAngle, endAngle);
        ctx.strokeStyle = C.track;
        ctx.lineWidth = 14;
        ctx.lineCap = 'round';
        ctx.stroke();

        /* Value arc — gradient */
        if (speed > 0) {
            const grad = ctx.createLinearGradient(cx - r, cy, cx + r, cy);
            grad.addColorStop(0, C.cyan);
            grad.addColorStop(0.5, C.teal);
            grad.addColorStop(0.8, C.amber);
            grad.addColorStop(1, C.red);

            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, valueAngle);
            ctx.strokeStyle = grad;
            ctx.lineWidth = 14;
            ctx.lineCap = 'round';
            ctx.stroke();
        }

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

    /* ────────────────────────────────────────────────────────────
       RPM Gauge
       Smaller 220° arc with green → amber → red zones
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

        /* Zone backgrounds */
        const zones = [
            { from: 0, to: 0.6, color: '#c8e6c9' },  /* green zone */
            { from: 0.6, to: 0.8, color: '#fff9c4' }, /* amber zone */
            { from: 0.8, to: 1.0, color: '#ffcdd2' }, /* red zone */
        ];

        zones.forEach(z => {
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle + z.from * totalArc, startAngle + z.to * totalArc);
            ctx.strokeStyle = z.color;
            ctx.lineWidth = 12;
            ctx.lineCap = 'butt';
            ctx.stroke();
        });

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
       Tilt Indicator
       Crosshair with a dot representing lean
    ──────────────────────────────────────────────────────────── */
    function drawTilt(canvas, ax, ay) {
        const ctx = canvas.getContext('2d');
        const W = canvas.width;
        const H = canvas.height;
        ctx.clearRect(0, 0, W, H);

        const cx = W / 2;
        const cy = H / 2;
        const r = Math.min(W, H) / 2 - 4;

        /* Outer ring */
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.strokeStyle = C.track;
        ctx.lineWidth = 2;
        ctx.stroke();

        /* Inner ring */
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.5, 0, Math.PI * 2);
        ctx.strokeStyle = C.track;
        ctx.lineWidth = 1;
        ctx.stroke();

        /* Crosshair */
        ctx.beginPath();
        ctx.moveTo(cx - r, cy);
        ctx.lineTo(cx + r, cy);
        ctx.moveTo(cx, cy - r);
        ctx.lineTo(cx, cy + r);
        ctx.strokeStyle = '#d1d5db';
        ctx.lineWidth = 1;
        ctx.stroke();

        /* Dot — map accelerometer to position (clamp to ring) */
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

    return { drawSpeedometer, drawRPMGauge, drawTilt };
})();
