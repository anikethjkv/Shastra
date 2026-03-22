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
        rpmBg: null,
    };




    function createRPMBackground(W, H, r, cx, cy, maxRPM) {
        const c = document.createElement('canvas');
        c.width = W; c.height = H;
        const ctx = c.getContext('2d');

        const trackWidth = 32;
        const xStart = cx - r;
        const yStart = cy;
        const tiltX = 30;
        const radius = 12; // Subtle inner radius as requested

        /* Track Path: Vertical angled -> Pivot with Inner Rounding -> Horizontal */
        ctx.beginPath();
        ctx.lineCap = 'butt';
        ctx.lineJoin = 'round'; // Rounds the outer automatically
        ctx.lineWidth = trackWidth;
        ctx.strokeStyle = C.track;

        ctx.moveTo(xStart - tiltX, yStart);
        
        const topY = yStart - r;
        
        // Manual inner rounding by using arcTo near the sharp pivot point
        ctx.lineTo(xStart - (radius * (tiltX / r)), topY + radius); 
        ctx.arcTo(xStart, topY, xStart + radius, topY, radius);
        
        ctx.lineTo(cx + r, topY);
        
        ctx.stroke();

        /* Ticks and Labels */
        ctx.fillStyle = C.dim;
        ctx.font = '700 14px Inter, sans-serif';
        ctx.textAlign = 'center';
        
        for (let i = 0; i <= 5; i++) {
            const val = i * 1000;
            const pct = val / maxRPM;
            let tx, ty;

            if (pct <= 0.3) {
                const vPct = pct / 0.3;
                tx = (xStart - tiltX) + vPct * tiltX - 45;
                ty = yStart - (vPct * (yStart - topY));
            } else {
                const hPct = (pct - 0.3) / 0.7;
                tx = xStart + hPct * ( (cx + r) - xStart );
                ty = topY - 25;
            }
            ctx.fillText(val, tx, ty);
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

        const cx = W / 2;
        const cy = H * 0.82; 
        const r = Math.min(W, H) * 0.65;
        const trackWidth = 32;

        if (!cache.rpmBg) {
            cache.rpmBg = createRPMBackground(W, H, r, cx, cy, maxRPM);
        }
        ctx.drawImage(cache.rpmBg, 0, 0);

        /* Value Bar */
        const pct = Math.min(rpm / maxRPM, 1);
        if (pct > 0) {
            const xOffset = cx - r;
            const yOffset = cy;
            const topY = yOffset - r;
            const tiltX = 30;
            const radius = 12;

            ctx.beginPath();
            ctx.moveTo(xOffset - tiltX, yOffset);
            
            if (pct <= 0.3) {
                const vPct = pct / 0.3;
                ctx.lineTo((xOffset - tiltX) + vPct * tiltX, yOffset - (vPct * (yOffset - topY)));
            } else {
                ctx.lineTo(xOffset - (radius * (tiltX / r)), topY + radius); 
                ctx.arcTo(xOffset, topY, xOffset + radius, topY, radius);
                const hPct = (pct - 0.3) / 0.7;
                ctx.lineTo(xOffset + hPct * ( (cx + r) - xOffset ), topY);
            }

            let grad = C.green;
            if (pct > 0.8) grad = C.red;
            else if (pct > 0.6) grad = C.amber;

            ctx.strokeStyle = grad;
            ctx.lineWidth = trackWidth;
            ctx.lineCap = 'butt';
            ctx.lineJoin = 'round';
            ctx.stroke();
        }

        /* Readouts */
        ctx.fillStyle = C.text;
        ctx.font = '900 110px Inter, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(Math.round(speed), cx + 25, cy - r/2 + 50);
        
        ctx.font = '800 24px Inter, sans-serif';
        ctx.fillStyle = C.dim;
        ctx.fillText('KM/H', cx + 25, cy - r/2 + 90);
        
        ctx.font = '700 18px Inter, sans-serif';
        ctx.fillText(Math.round(rpm) + ' RPM', cx + 25, cy - r/2 - 40);
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
