/* ═══════════════════════════════════════════════════════════════
   Shastra EV Dashboard — Application Logic
   Optimised for Raspberry Pi (minimal DOM writes, 1s poll, dirty flags)
   ═══════════════════════════════════════════════════════════════ */

(() => {
    'use strict';

    const STREAM_URL = '/api/stream';
    const fallbackData = '/api/data';
    const $ = id => document.getElementById(id);

    /* ── Cached DOM refs ──────────────────────────────────────── */
    const el = {
        phaseU:       $('phase-u'),
        phaseV:       $('phase-v'),
        phaseW:       $('phase-w'),
        phaseIU:      $('phase-i-u'),
        phaseIV:      $('phase-i-v'),
        phaseIW:      $('phase-i-w'),
        rpmValue:     $('rpm-value'),
        speedValue:   $('speed-value'),
        hvsVoltage:   $('hvs-voltage'),
        socPct:       $('soc-pct'),
        socLabel:     $('soc-label'),
        battFill:     $('battery-fill'),
        tiltDeg:      $('tilt-deg'),

        motorPower:   $('motor-power'),
        totalDist:    $('total-distance'),
        faultStatus:  $('fault-status'),
        warnStatus:   $('warn-status'),
        motorTemp:    $('motor-temp'),
        ctrlTemp:     $('ctrl-temp'),
        battTemp:     $('batt-temp'),
        smokeIcon:    $('smoke-icon'),
        smokeLabel:   $('smoke-label'),
        gpsStatus:    $('gps-status'),
        lteStatus:    $('lte-status'),
        canStatus:    $('can-status'),
        bmsCurrent:   $('bms-current'),
        bmsCycles:    $('bms-cycles'),
        bmsCap:       $('bms-cap'),
        bmsStrings:   $('bms-strings'),
        ntc1:         $('ntc1'),
        ntc2:         $('ntc2'),
        ntc3:         $('ntc3'),
        ntc4:         $('ntc4'),
        ntc5:         $('ntc5'),
        // Switch indicators
        indLeft:      $('ind-left'),
        indRight:     $('ind-right'),
        indHorn:      $('ind-horn'),
        indBrake:     $('ind-brake'),
        indHead:      $('ind-head'),
        indHiBeam:    $('ind-hibeam'),
    };

    const rpmCanvas   = $('rpm-gauge');
    const speedCanvas = $('speed-gauge');
    const tiltCanvas  = $('tilt-canvas');

    let prev = {};


    /* ── Helpers ──────────────────────────────────────────────── */
    function setText(e, v) { if (e && e._l !== v) { e.textContent = v; e._l = v; } }
    function setHTML(e, v) { if (e && e._h !== v) { e.innerHTML = v; e._h = v; } }
    function pad2(n) { return n < 10 ? '0' + n : '' + n; }

    function setIndicator(e, active) {
        if (e) {
            if (active) e.classList.add('active');
            else e.classList.remove('active');
        }
    }

    function socStatus(soc) {
        if (soc >= 80) return { label: 'GOOD', color: '#2e7d32' };
        if (soc >= 50) return { label: 'FAIR', color: '#f57f17' };
        if (soc >= 20) return { label: 'LOW',  color: '#e65100' };
        return { label: 'CRITICAL', color: '#d32f2f' };
    }

    function connClass(active) { return active ? 'conn-val online' : 'conn-val offline'; }

    /* ── Main update ──────────────────────────────────────────── */
    function updateUI(d) {


        /* Phase voltages */
        setHTML(el.phaseU, (d.phase_v_a || 0).toFixed(1) + '<small>V</small>');
        setHTML(el.phaseV, (d.phase_v_b || 0).toFixed(1) + '<small>V</small>');
        setHTML(el.phaseW, (d.phase_v_c || 0).toFixed(1) + '<small>V</small>');

        /* Phase currents */
        setHTML(el.phaseIU, (d.phase_i_a || 0).toFixed(1) + '<small>A</small>');
        setHTML(el.phaseIV, (d.phase_i_b || 0).toFixed(1) + '<small>A</small>');
        setHTML(el.phaseIW, (d.phase_i_c || 0).toFixed(1) + '<small>A</small>');

        /* Gauge update (Hockey stick + Speed) */
        const rpm = Math.round(d.motor_rpm || 0);
        const speed = d.vehicle_speed || d.speed_kmh || 0;
        const spdRound = Math.round(speed);
        
        if (prev.rpm !== rpm || prev.spd !== spdRound) {
            Gauges.drawRPMGauge(rpmCanvas, rpm, speed, 5000);
            prev.rpm = rpm;
            prev.spd = spdRound;
        }

        /* Battery / SOC */
        const hvs = (d.bms_total_voltage || d.batt_v || 0).toFixed(0);
        const soc = Math.round(d.bms_soc || d.batt_soc || 0);
        setText(el.hvsVoltage, hvs + 'V');
        setText(el.socPct, soc + '%');
        const ss = socStatus(soc);
        if (el.socLabel) { el.socLabel.textContent = ss.label; el.socLabel.style.color = ss.color; }
        if (el.battFill) {
            el.battFill.style.width = Math.min(soc, 100) + '%';
            el.battFill.style.background = soc >= 50
                ? 'linear-gradient(90deg, #2e7d32, #66bb6a)'
                : soc >= 20 ? 'linear-gradient(90deg, #f57f17, #ffb300)'
                : 'linear-gradient(90deg, #d32f2f, #ef5350)';
        }

        /* BMS extras */
        const cur = (d.bms_current || d.batt_i || 0).toFixed(1);
        setText(el.bmsCurrent, cur + 'A');

        /* BMS capacity & strings */
        const remCap = d.bms_rem_cap;
        const fullCap = d.bms_full_cap;
        if (remCap != null && fullCap != null && fullCap > 0) {
            setText(el.bmsCap, Math.round(remCap) + '/' + Math.round(fullCap) + 'mAh');
        } else if (remCap != null) {
            setText(el.bmsCap, Math.round(remCap) + 'mAh');
        }
        if (d.bms_strings != null) setText(el.bmsStrings, Math.round(d.bms_strings) + 'S');

        /* BMS NTC probe temps */
        const ntcKeys = ['bms_ntc1','bms_ntc2','bms_ntc3','bms_ntc4','bms_ntc5'];
        const ntcEls = [el.ntc1, el.ntc2, el.ntc3, el.ntc4, el.ntc5];
        for (let i = 0; i < 5; i++) {
            const v = d[ntcKeys[i]];
            if (v != null) setText(ntcEls[i], v.toFixed(1) + '°');
        }
        setText(el.bmsCycles, Math.round(d.bms_cycles || 0));

        /* Tilt */
        const ax = d.accel_x || 0, ay = d.accel_y || 0;
        const tilt = Math.sqrt(ax * ax + ay * ay).toFixed(1);
        setText(el.tiltDeg, tilt + '°');
        if (prev.ax !== ax || prev.ay !== ay) { Gauges.drawTilt(tiltCanvas, ax, ay); prev.ax = ax; prev.ay = ay; }

        /* Power & distance */
        const pwr = Math.round(d.motor_pwr || 0);
        setHTML(el.motorPower, pwr + '<small>W</small>');
        const dist = (d.total_distance || 0).toFixed(1);
        setHTML(el.totalDist, dist + '<small>km</small>');

        /* Faults (combined from all sources) */
        const totalFaults = (d.faults || 0) | (d.faults2 || 0) | (d.faults3 || 0);
        if (totalFaults > 0) {
            setText(el.faultStatus, 'ACTIVE');
            el.faultStatus.className = 'strip-value strip-fault';
        } else {
            setText(el.faultStatus, 'NONE');
            el.faultStatus.className = 'strip-value strip-ok';
        }

        /* Warnings (combined from all sources) */
        const totalWarns = (d.warnings || 0) | (d.warnings2 || 0);
        if (totalWarns > 0) {
            setText(el.warnStatus, 'ACTIVE');
            el.warnStatus.className = 'strip-value strip-warn';
        } else {
            setText(el.warnStatus, 'NONE');
            el.warnStatus.className = 'strip-value strip-ok';
        }

        /* Temperatures */
        setText(el.motorTemp, Math.round(d.motor_temp || 0) + '°C');
        setText(el.ctrlTemp, Math.round(d.ctrl_temp || 0) + '°C');
        setText(el.battTemp, Math.round(d.batt_temp || d.bms_ntc1 || 0) + '°C');

        /* Smoke sensor */
        const smokeDetected = (d.smoke_detected || 0) >= 1;
        if (smokeDetected) {
            el.smokeIcon.classList.add('alert');
            el.smokeLabel.classList.add('alert');
            setText(el.smokeLabel, 'ALERT!');
        } else {
            el.smokeIcon.classList.remove('alert');
            el.smokeLabel.classList.remove('alert');
            setText(el.smokeLabel, 'CLEAR');
        }

        /* Switch indicators */
        setIndicator(el.indLeft,   d.sw_left >= 1);
        setIndicator(el.indRight,  d.sw_right >= 1);
        setIndicator(el.indHorn,   d.sw_horn >= 1);
        setIndicator(el.indBrake,  d.sw_brake >= 1);
        setIndicator(el.indHead,   d.sw_head >= 1);
        setIndicator(el.indHiBeam, d.sw_hi_beam >= 1);

        /* Connectivity */
        const gpsLock = (d.gps_lock || 0) >= 2;
        const lteOn   = (d.lte_status || 0) >= 1;
        setText(el.gpsStatus, gpsLock ? 'LOCK' : 'NO FIX');
        el.gpsStatus.className = connClass(gpsLock);
        setText(el.lteStatus, lteOn ? 'ON' : 'OFF');
        el.lteStatus.className = connClass(lteOn);
        setText(el.canStatus, 'OK');
        el.canStatus.className = connClass(true);
    }

    /* ── Demo data (shown when API is offline) ────────────────── */
    function showDemoData() {
        updateUI({
            phase_v_a: 47.3, phase_v_b: 47.6, phase_v_c: 49.7,
            motor_rpm: 1700, vehicle_speed: 30,
            bms_total_voltage: 144, bms_soc: 61, bms_current: 12.5, bms_cycles: 42,
            accel_x: 0.7, accel_y: 0.3,
            motor_pwr: 850, total_distance: 23.4,
            motor_temp: 45, ctrl_temp: 38, batt_temp: 32,
            smoke_detected: 0,
            sw_left: 0, sw_right: 0, sw_horn: 0, sw_brake: 1, sw_head: 1, sw_hi_beam: 0,
            gps_lock: 3, lte_status: 1,
        });
    }

    /* ── SSE Stream ───────────────────────────────────────────── */
    function connectStream() {
        const source = new EventSource(STREAM_URL);
        
        source.onmessage = (e) => {

            const data = JSON.parse(e.data);
            updateUI(data);
        };
        
        source.onerror = () => {

            source.close();
            setTimeout(connectStream, 2000);
            if (Object.keys(prev).length === 0) showDemoData();
        };
    }



    /* ── Mode selector ────────────────────────────────────────── */
    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
    });

    /* ── Init ─────────────────────────────────────────────────── */
    /* Gauges */
    Gauges.drawRPMGauge(rpmCanvas, 0, 0);
    Gauges.drawTilt(tiltCanvas, 0, 0);


    
    // Connect to realtime server stream
    connectStream();
})();
