/* ═══════════════════════════════════════════════════════════════
   Shastra EV Dashboard — Application Logic
   Optimised for Raspberry Pi (minimal DOM writes, 1s poll, dirty flags)
   ═══════════════════════════════════════════════════════════════ */

(() => {
    'use strict';

    const STREAM_URL = '/api/stream';
    const fallbackData = '/api/data';
    const $ = id => document.getElementById(id);

    const demoMode = (() => {
        try {
            return new URLSearchParams(window.location.search).get('demo') === '1';
        } catch {
            return false;
        }
    })();

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
        odometerValue: $('odometer-value'),
        hvsVoltage:   $('hvs-voltage'),
        socPct:       $('soc-pct'),
        socLabel:     $('soc-label'),
        battFill:     $('battery-fill'),
        tiltDeg:      $('tilt-deg'),

        motorPower:   $('motor-power'),
        totalDist:    $('total-distance'),
        faultStatus:  $('fault-status'),
        warnStatus:   $('warn-status'),
        hvStatusBadge: $('hv-status-badge'),
        hvStatusText: $('hv-status-text'),
        topFaultBtn:  $('top-fault-btn'),
        topWarnBtn:   $('top-warn-btn'),
        topGpsPill:   $('top-gps-pill'),
        topLtePill:   $('top-lte-pill'),
        alertPopover: $('alert-popover'),
        alertTitle:   $('alert-popover-title'),
        alertBody:    $('alert-popover-body'),
        alertClose:   $('alert-popover-close'),
        motorTemp:    $('motor-temp'),
        ctrlTemp:     $('ctrl-temp'),
        battTemp:     $('batt-temp'),
        smokeStatus:  $('smoke-status'),
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
        mapPlaceholder: $('map-placeholder'),
        mapCanvas:    $('map-canvas'),
        mapStatus:    $('map-status'),
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
    const latestAlerts = {
        faults: { total: 0, f1: 0, f2: 0, f3: 0 },
        warnings: { total: 0, w1: 0, w2: 0 },
    };

    const FAULTS_1 = [
        'Averaged controller over voltage',
        'Averaged phase over current',
        'Current sensor calibration',
        'Current sensor over current',
        'Controller over temperature',
        'Motor Hall sensor fault',
        'Averaged motor over temperature',
        'POST static gating test',
        'Network communication timeout',
        'Instantaneous phase over current',
        'Motor over temperature',
        'Throttle voltage outside range',
        'Instantaneous controller over voltage',
        'Internal error',
        'POST dynamic gating test',
        'Instantaneous undervoltage',
    ];

    const FAULTS_2 = [
        'Parameter CRC',
        'Current scaling',
        'Voltage scaling',
        'Headlight undervoltage',
        'Parameter 3 CRC',
        'CAN bus',
        'Hall stall',
        'Bootloader (not used)',
        'Parameter 2 CRC',
        'Hall vs sensorless position',
        'Spare',
        'Spare',
        'Remote CAN fault',
        'Open phase fault',
        'Analog brake voltage out of range',
        'Reserved bit 15',
    ];

    const FAULTS_3 = [
        'Encoder sin voltage range',
        'Encoder cos voltage range',
        'Analog input saturation fault',
        'Dual throttle out of range bit 3',
        'Reserved bit 4',
        'Reserved bit 5',
        'Reserved bit 6',
        'Reserved bit 7',
        'Reserved bit 8',
        'Reserved bit 9',
        'Reserved bit 10',
        'Reserved bit 11',
        'Reserved bit 12',
        'Reserved bit 13',
        'Reserved bit 14',
        'Reserved bit 15',
    ];

    const WARNINGS_1 = [
        'Communication timeout',
        'Hall sensor',
        'Hall stall',
        'Wheel speed sensor',
        'CAN bus',
        'Hall illegal sector',
        'Hall illegal transition',
        'Low battery voltage foldback',
        'High battery voltage foldback',
        'Motor temperature foldback',
        'Controller over temperature foldback',
        'Low SOC foldback',
        'High SOC foldback',
        'I2T overload foldback',
        'Low-temperature battery/controller foldback',
        'Obsolete - BMS communication timeout',
    ];

    const WARNINGS_2 = [
        'Throttle out of range warning',
        'Dual speed sensor missing pulses warning',
        'Dual speed sensor no pulses warning',
        'Dynamic flash full warning',
        'Dynamic flash read error',
        'Dynamic flash write error',
        'Parameters3 missing warning',
        'Missed CAN message',
        'High battery temperature foldback',
        'ADC saturation warning',
        'Reserved bit 10',
        'Reserved bit 11',
        'Reserved bit 12',
        'Reserved bit 13',
        'Reserved bit 14',
        'Reserved bit 15',
    ];


    /* ── Helpers ──────────────────────────────────────────────── */
    function setText(e, v) { if (e && e._l !== v) { e.textContent = v; e._l = v; } }
    function setHTML(e, v) { if (e && e._h !== v) { e.innerHTML = v; e._h = v; } }
    function pad2(n) { return n < 10 ? '0' + n : '' + n; }

    function setClassName(e, v) {
        if (e && e.className !== v) e.className = v;
    }

    function setTopState(e, level) {
        if (!e) return;
        e.classList.remove('ok', 'warn', 'fault', 'offline');
        e.classList.add(level);
    }

    function activeBits(mask, labels) {
        const m = Number(mask) || 0;
        const out = [];
        for (let i = 0; i < 16; i++) {
            if ((m & (1 << i)) !== 0) out.push(`bit ${i}: ${labels[i] || `Unknown bit ${i}`}`);
        }
        return out;
    }

    function hexMask(mask) {
        const m = Number(mask) || 0;
        return `0x${(m >>> 0).toString(16).toUpperCase().padStart(4, '0')}`;
    }

    function formatMaskDetails(title, mask, labels) {
        const entries = activeBits(mask, labels);
        const head = `${title} (${hexMask(mask)})`;
        if (!entries.length) return `${head}\n  - none`;
        return `${head}\n  - ${entries.join('\n  - ')}`;
    }

    function openAlertPopover(type) {
        if (!el.alertPopover || !el.alertTitle || !el.alertBody) return;
        const isFault = type === 'fault';
        const data = isFault ? latestAlerts.faults : latestAlerts.warnings;
        const total = data.total || 0;

        el.alertTitle.textContent = isFault ? 'FAULT DETAILS' : 'WARNING DETAILS';
        if (total <= 0) {
            el.alertBody.textContent = isFault ? 'No active faults.' : 'No active warnings.';
        } else if (isFault) {
            el.alertBody.textContent =
                `${formatMaskDetails('faults', data.f1, FAULTS_1)}\n\n` +
                `${formatMaskDetails('faults2', data.f2, FAULTS_2)}\n\n` +
                `${formatMaskDetails('faults3', data.f3, FAULTS_3)}\n\n` +
                `combined(mask): ${hexMask(data.total)}`;
        } else {
            el.alertBody.textContent =
                `${formatMaskDetails('warnings', data.w1, WARNINGS_1)}\n\n` +
                `${formatMaskDetails('warnings2', data.w2, WARNINGS_2)}\n\n` +
                `combined(mask): ${hexMask(data.total)}`;
        }

        el.alertPopover.classList.add('show');
        el.alertPopover.setAttribute('aria-hidden', 'false');
    }

    function closeAlertPopover() {
        if (!el.alertPopover) return;
        el.alertPopover.classList.remove('show');
        el.alertPopover.setAttribute('aria-hidden', 'true');
    }

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

    let mapState = {
        lat: null,
        lon: null,
        ready: false,
        map: null,
        marker: null,
        watchId: null,
    };

    const GOOGLE_MAPS_CB = '__initShastraGoogleMaps';

    function loadGoogleMapsApi(apiKey) {
        if (window.google && window.google.maps) return Promise.resolve();
        if (!apiKey) return Promise.reject(new Error('Missing API key'));

        return new Promise((resolve, reject) => {
            window[GOOGLE_MAPS_CB] = () => resolve();
            const script = document.createElement('script');
            script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places&callback=${GOOGLE_MAPS_CB}`;
            script.async = true;
            script.defer = true;
            script.onerror = () => reject(new Error('Failed to load Google Maps API'));
            document.head.appendChild(script);
        });
    }

    function mapViewUrl(lat, lon) {
        return `https://www.google.com/maps/search/?api=1&query=${lat},${lon}`;
    }

    function updateMapPosition(lat, lon, heading) {
        mapState.lat = Number(lat);
        mapState.lon = Number(lon);
        mapState.ready = Number.isFinite(mapState.lat) && Number.isFinite(mapState.lon);
        if (!mapState.ready) return;

        const pos = { lat: mapState.lat, lng: mapState.lon };
        if (mapState.marker) {
            mapState.marker.setPosition(pos);
            mapState.marker.setIcon({
                path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
                scale: 5,
                rotation: Number.isFinite(heading) ? heading : 0,
                fillColor: '#1a73e8',
                fillOpacity: 1,
                strokeColor: '#ffffff',
                strokeWeight: 1.8,
            });
        }
        if (mapState.map) mapState.map.setCenter(pos);
        if (el.mapStatus) setText(el.mapStatus, 'LIVE GPS');
    }

    function openNavigationWindow() {
        let navUrl = 'nav.html';
        if (mapState.ready) {
            navUrl += `?lat=${encodeURIComponent(mapState.lat)}&lon=${encodeURIComponent(mapState.lon)}`;
        }
        window.open(navUrl, '_blank', 'noopener,noreferrer');
    }

    function initGoogleMapObjects() {
        if (!el.mapCanvas || !window.google || !window.google.maps) return;

        mapState.map = new google.maps.Map(el.mapCanvas, {
            center: { lat: 12.9716, lng: 77.5946 },
            zoom: 14,
            disableDefaultUI: true,
            zoomControl: false,
            mapTypeControl: false,
            streetViewControl: false,
            fullscreenControl: false,
            gestureHandling: 'none',
        });

        mapState.marker = new google.maps.Marker({
            map: mapState.map,
            title: 'Current location',
            clickable: false,
        });
    }

    function initMapPanel() {
        if (!el.mapPlaceholder || !el.mapCanvas || !el.mapStatus) return;
        el.mapPlaceholder.addEventListener('click', openNavigationWindow);

        if (!navigator.geolocation) {
            setText(el.mapStatus, 'GEO UNSUPPORTED');
            return;
        }

        setText(el.mapStatus, 'LOCATING...');
        mapState.watchId = navigator.geolocation.watchPosition(
            (pos) => {
                updateMapPosition(pos.coords.latitude, pos.coords.longitude, pos.coords.heading);
            },
            () => {
                setText(el.mapStatus, 'GPS BLOCKED');
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 10000,
            },
        );

        const mapsKeyFromWindow = typeof window.GOOGLE_MAPS_API_KEY === 'string' ? window.GOOGLE_MAPS_API_KEY.trim() : '';
        const mapsKeyFromStorage = (typeof window.localStorage !== 'undefined' && typeof window.localStorage.getItem === 'function')
            ? String(window.localStorage.getItem('GOOGLE_MAPS_API_KEY') || '').trim()
            : '';
        const mapsKey = mapsKeyFromWindow || mapsKeyFromStorage;
        if (!mapsKey) {
            setText(el.mapStatus, 'SET GOOGLE_MAPS_API_KEY');
            return;
        }

        loadGoogleMapsApi(mapsKey)
            .then(() => {
                initGoogleMapObjects();
                if (mapState.ready) updateMapPosition(mapState.lat, mapState.lon);
            })
            .catch(() => {
                setText(el.mapStatus, 'MAP LOAD ERROR');
            });
    }

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
            if (rpmCanvas && typeof Gauges !== 'undefined' && Gauges && typeof Gauges.drawRPMGauge === 'function') {
                Gauges.drawRPMGauge(rpmCanvas, rpm, speed, 5000);
            }
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
        if (prev.ax !== ax || prev.ay !== ay) {
            if (tiltCanvas && typeof Gauges !== 'undefined' && Gauges && typeof Gauges.drawTilt === 'function') {
                Gauges.drawTilt(tiltCanvas, ax, ay);
            }
            prev.ax = ax;
            prev.ay = ay;
        }

        /* Power & distance */
        const pwr = Math.round(d.motor_pwr || 0);
        setHTML(el.motorPower, pwr + '<small>W</small>');
        const dist = (d.total_distance || 0).toFixed(1);
        setHTML(el.totalDist, dist + '<small>km</small>');
        setHTML(el.odometerValue, dist + '<small>km</small>');

        /* Faults (combined from all sources) */
        const totalFaults = (d.faults || 0) | (d.faults2 || 0) | (d.faults3 || 0);
        latestAlerts.faults = {
            total: totalFaults,
            f1: (d.faults || 0),
            f2: (d.faults2 || 0),
            f3: (d.faults3 || 0),
        };
        if (totalFaults > 0) {
            setText(el.faultStatus, 'ACTIVE');
            setClassName(el.faultStatus, 'strip-value strip-fault');
            setTopState(el.topFaultBtn, 'fault');
            if (el.topFaultBtn) el.topFaultBtn.title = 'Faults active (tap for details)';
        } else {
            setText(el.faultStatus, 'NONE');
            setClassName(el.faultStatus, 'strip-value strip-ok');
            setTopState(el.topFaultBtn, 'ok');
            if (el.topFaultBtn) el.topFaultBtn.title = 'No active faults';
        }

        /* Warnings (combined from all sources) */
        const totalWarns = (d.warnings || 0) | (d.warnings2 || 0);
        latestAlerts.warnings = {
            total: totalWarns,
            w1: (d.warnings || 0),
            w2: (d.warnings2 || 0),
        };
        if (totalWarns > 0) {
            setText(el.warnStatus, 'ACTIVE');
            setClassName(el.warnStatus, 'strip-value strip-warn');
            setTopState(el.topWarnBtn, 'warn');
            if (el.topWarnBtn) el.topWarnBtn.title = 'Warnings active (tap for details)';
        } else {
            setText(el.warnStatus, 'NONE');
            setClassName(el.warnStatus, 'strip-value strip-ok');
            setTopState(el.topWarnBtn, 'ok');
            if (el.topWarnBtn) el.topWarnBtn.title = 'No active warnings';
        }

        /* Temperatures */
        setText(el.motorTemp, Math.round(d.motor_temp || 0) + '°C');
        setText(el.ctrlTemp, Math.round(d.ctrl_temp || 0) + '°C');
        setText(el.battTemp, Math.round(d.batt_temp || d.bms_ntc1 || 0) + '°C');

        /* Smoke sensor */
        const smokeDetected = (d.smoke_detected || 0) >= 1;
        if (smokeDetected) {
            if (el.smokeStatus) el.smokeStatus.classList.add('smoke-alert');
            if (el.smokeIcon) el.smokeIcon.classList.add('alert');
            if (el.smokeLabel) el.smokeLabel.classList.add('alert');
            setText(el.smokeLabel, 'ALERT!');
        } else {
            if (el.smokeStatus) el.smokeStatus.classList.remove('smoke-alert');
            if (el.smokeIcon) el.smokeIcon.classList.remove('alert');
            if (el.smokeLabel) el.smokeLabel.classList.remove('alert');
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
        setClassName(el.gpsStatus, connClass(gpsLock));
        setText(el.lteStatus, lteOn ? 'ON' : 'OFF');
        setClassName(el.lteStatus, connClass(lteOn));
        setText(el.canStatus, 'OK');
        setClassName(el.canStatus, connClass(true));

        setTopState(el.topGpsPill, gpsLock ? 'ok' : 'offline');
        setTopState(el.topLtePill, lteOn ? 'ok' : 'offline');

        /* HV Status */
        const hvOn = (d.hv_active || 0) >= 1;
        if (el.hvStatusBadge) {
            if (hvOn) el.hvStatusBadge.classList.add('active');
            else el.hvStatusBadge.classList.remove('active');
        }
        setText(el.hvStatusText, hvOn ? 'HV ACTIVE' : 'HV OFF');
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

    function startDemoAnimation() {
        const t0 = performance.now();
        setInterval(() => {
            const t = (performance.now() - t0) / 1000;
            const speed = 45 + 35 * Math.sin(t * 0.8);
            const rpm = Math.max(0, Math.round(500 + speed * 55 + 350 * Math.sin(t * 1.6)));
            updateUI({
                phase_v_a: 35 + 2 * Math.sin(t * 1.1),
                phase_v_b: 35 + 2 * Math.sin(t * 1.1 + 1.2),
                phase_v_c: 35 + 2 * Math.sin(t * 1.1 + 2.4),
                phase_i_a: 0.2 + 1.3 * Math.sin(t * 1.7),
                phase_i_b: 0.2 + 1.3 * Math.sin(t * 1.7 + 1.2),
                phase_i_c: 0.2 + 1.3 * Math.sin(t * 1.7 + 2.4),
                motor_rpm: rpm,
                vehicle_speed: Math.max(0, speed),
                motor_pwr: Math.max(0, Math.round(speed * 40)),
                total_distance: (t * 0.02),
                bms_total_voltage: 70,
                bms_soc: 100,
                bms_current: Math.max(0, 2 + 6 * Math.sin(t * 0.8)),
                bms_cycles: 0,
                accel_x: 0.8 * Math.sin(t * 0.7),
                accel_y: 0.8 * Math.cos(t * 0.7),
                motor_temp: 30,
                ctrl_temp: 30,
                batt_temp: 29,
                smoke_detected: 0,
                sw_left: (Math.sin(t * 2.8) > 0.85) ? 1 : 0,
                sw_right: (Math.sin(t * 2.8 + 1.7) > 0.85) ? 1 : 0,
                sw_horn: 0,
                sw_brake: (speed < 5) ? 1 : 0,
                sw_head: 1,
                sw_hi_beam: 0,
                gps_lock: 3,
                lte_status: 1,
                faults: 0,
                faults2: 0,
                faults3: 0,
                warnings: 0,
                warnings2: 0,
            });
        }, 50);
    }

    /* ── SSE Stream ───────────────────────────────────────────── */
    function connectStream() {
        const source = new EventSource(STREAM_URL);
        
        source.onmessage = (e) => {

            try {
                const data = JSON.parse(e.data);
                updateUI(data);
            } catch {
                // Ignore malformed frames
            }
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

    if (el.topFaultBtn) el.topFaultBtn.addEventListener('click', () => openAlertPopover('fault'));
    if (el.topWarnBtn) el.topWarnBtn.addEventListener('click', () => openAlertPopover('warn'));
    if (el.alertClose) el.alertClose.addEventListener('click', closeAlertPopover);
    if (el.alertPopover) {
        el.alertPopover.addEventListener('click', (evt) => {
            if (evt.target === el.alertPopover) closeAlertPopover();
        });
    }

    /* ── Init ─────────────────────────────────────────────────── */
    /* Gauges */
    if (rpmCanvas && typeof Gauges !== 'undefined' && Gauges && typeof Gauges.drawRPMGauge === 'function') {
        Gauges.drawRPMGauge(rpmCanvas, 0, 0);
    }
    if (tiltCanvas && typeof Gauges !== 'undefined' && Gauges && typeof Gauges.drawTilt === 'function') {
        Gauges.drawTilt(tiltCanvas, 0, 0);
    }

    initMapPanel();


    
    if (demoMode) {
        startDemoAnimation();
    } else {
        // Connect to realtime server stream
        connectStream();
    }
})();
