(() => {
    'use strict';

    const STREAM_URL = '/api/stream';
    const $ = (id) => document.getElementById(id);

    const el = {
        speed: $('nav-speed'),
        battery: $('nav-battery'),
        map: $('nav-map'),
        destination: $('nav-destination'),
        routeBtn: $('nav-route-btn'),
        clearBtn: $('nav-clear-btn'),
        status: $('nav-status'),
    };

    const state = {
        lat: null,
        lon: null,
        heading: 0,
        ready: false,
        map: null,
        marker: null,
        directionsService: null,
        directionsRenderer: null,
        destinationText: '',
    };

    const GOOGLE_MAPS_CB = '__initShastraNavMaps';

    function setText(node, value) {
        if (!node || node._last === value) return;
        node.textContent = value;
        node._last = value;
    }

    function keyFromConfig() {
        const fromWindow = typeof window.GOOGLE_MAPS_API_KEY === 'string'
            ? window.GOOGLE_MAPS_API_KEY.trim()
            : '';
        const fromStorage = (typeof window.localStorage !== 'undefined' && typeof window.localStorage.getItem === 'function')
            ? String(window.localStorage.getItem('GOOGLE_MAPS_API_KEY') || '').trim()
            : '';
        return fromWindow || fromStorage;
    }

    function loadGoogleMapsApi(apiKey) {
        if (window.google && window.google.maps) return Promise.resolve();
        if (!apiKey) return Promise.reject(new Error('missing key'));

        return new Promise((resolve, reject) => {
            window[GOOGLE_MAPS_CB] = () => resolve();
            const script = document.createElement('script');
            script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places&callback=${GOOGLE_MAPS_CB}`;
            script.async = true;
            script.defer = true;
            script.onerror = () => reject(new Error('maps load failed'));
            document.head.appendChild(script);
        });
    }

    function readStartPosition() {
        try {
            const q = new URLSearchParams(window.location.search);
            const lat = Number(q.get('lat'));
            const lon = Number(q.get('lon'));
            if (Number.isFinite(lat) && Number.isFinite(lon)) {
                state.lat = lat;
                state.lon = lon;
                state.ready = true;
            }
        } catch {
            // ignore malformed query
        }
    }

    function baseMapOptions() {
        return {
            center: state.ready ? { lat: state.lat, lng: state.lon } : { lat: 12.9716, lng: 77.5946 },
            zoom: 15,
            disableDefaultUI: true,
            zoomControl: false,
            mapTypeControl: false,
            streetViewControl: false,
            fullscreenControl: false,
        };
    }

    function navMapOptions() {
        return {
            disableDefaultUI: false,
            zoomControl: true,
            mapTypeControl: true,
            streetViewControl: true,
            fullscreenControl: true,
        };
    }

    function initMapObjects() {
        if (!el.map || !window.google || !window.google.maps) return;

        state.map = new google.maps.Map(el.map, baseMapOptions());

        state.marker = new google.maps.Marker({
            map: state.map,
            title: 'Current location',
            clickable: false,
        });

        state.directionsService = new google.maps.DirectionsService();
        state.directionsRenderer = new google.maps.DirectionsRenderer({
            map: state.map,
            suppressMarkers: false,
            polylineOptions: { strokeColor: '#0f62fe', strokeWeight: 6 },
        });

        if (el.destination && google.maps.places && google.maps.places.Autocomplete) {
            const autocomplete = new google.maps.places.Autocomplete(el.destination, {
                fields: ['formatted_address', 'name'],
            });
            autocomplete.addListener('place_changed', () => {
                const place = autocomplete.getPlace();
                if (!place || !el.destination) return;
                if (place.formatted_address) el.destination.value = place.formatted_address;
                else if (place.name) el.destination.value = place.name;
            });
        }

        if (state.ready) applyLivePosition(state.lat, state.lon, state.heading);
    }

    function applyLivePosition(lat, lon, heading) {
        state.lat = Number(lat);
        state.lon = Number(lon);
        state.heading = Number.isFinite(heading) ? heading : 0;
        state.ready = Number.isFinite(state.lat) && Number.isFinite(state.lon);
        if (!state.ready) return;

        const pos = { lat: state.lat, lng: state.lon };

        if (state.marker) {
            state.marker.setPosition(pos);
            state.marker.setIcon({
                path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
                scale: 6,
                rotation: state.heading,
                fillColor: '#1a73e8',
                fillOpacity: 1,
                strokeColor: '#ffffff',
                strokeWeight: 2,
            });
        }

        if (state.map && !state.destinationText) state.map.setCenter(pos);
        setText(el.status, state.destinationText ? el.status.textContent : 'LIVE GPS');
    }

    function clearRoute() {
        state.destinationText = '';
        if (state.directionsRenderer) state.directionsRenderer.set('directions', null);
        if (el.destination) el.destination.value = '';
        if (state.map) state.map.setOptions(baseMapOptions());
        if (state.ready) setText(el.status, 'LIVE GPS');
    }

    function routeToDestination() {
        const destinationText = (el.destination && el.destination.value ? el.destination.value : '').trim();
        if (!destinationText) {
            setText(el.status, 'ENTER DESTINATION');
            return;
        }
        if (!state.ready) {
            setText(el.status, 'WAIT GPS');
            return;
        }
        if (!state.directionsService || !state.directionsRenderer) {
            setText(el.status, 'MAP NOT READY');
            return;
        }

        const origin = { lat: state.lat, lng: state.lon };
        state.directionsService.route(
            {
                origin,
                destination: destinationText,
                travelMode: google.maps.TravelMode.DRIVING,
                unitSystem: google.maps.UnitSystem.METRIC,
            },
            (result, status) => {
                if (status === 'OK' && result) {
                    state.destinationText = destinationText;
                    state.directionsRenderer.setDirections(result);
                    if (state.map) state.map.setOptions(navMapOptions());

                    const leg = result.routes?.[0]?.legs?.[0];
                    if (leg) setText(el.status, `${leg.distance?.text || ''} • ${leg.duration?.text || ''}`.trim());
                } else {
                    setText(el.status, 'ROUTE ERROR');
                }
            },
        );
    }

    function connectTelemetry() {
        const source = new EventSource(STREAM_URL);

        source.onmessage = (evt) => {
            try {
                const d = JSON.parse(evt.data);
                const spd = Math.max(0, Math.round(d.vehicle_speed || d.speed_kmh || 0));
                const soc = Math.round(d.bms_soc || d.batt_soc || 0);
                setText(el.speed, `${spd} KM/H`);
                setText(el.battery, `${soc}%`);
            } catch {
                // ignore malformed frames
            }
        };

        source.onerror = () => {
            source.close();
            setTimeout(connectTelemetry, 2000);
        };
    }

    function trackGeolocation() {
        if (!navigator.geolocation) {
            setText(el.status, 'GEO UNSUPPORTED');
            return;
        }

        setText(el.status, 'LOCATING...');
        navigator.geolocation.watchPosition(
            (pos) => {
                applyLivePosition(pos.coords.latitude, pos.coords.longitude, pos.coords.heading);
            },
            () => {
                setText(el.status, 'GPS BLOCKED');
            },
            {
                enableHighAccuracy: true,
                timeout: 12000,
                maximumAge: 10000,
            },
        );
    }

    function init() {
        if (el.routeBtn) el.routeBtn.addEventListener('click', routeToDestination);
        if (el.clearBtn) el.clearBtn.addEventListener('click', clearRoute);
        if (el.destination) {
            el.destination.addEventListener('keydown', (evt) => {
                if (evt.key === 'Enter') {
                    evt.preventDefault();
                    routeToDestination();
                }
            });
        }

        readStartPosition();
        connectTelemetry();

        const key = keyFromConfig();
        if (!key) {
            setText(el.status, 'SET GOOGLE_MAPS_API_KEY');
            return;
        }

        loadGoogleMapsApi(key)
            .then(() => {
                initMapObjects();
                trackGeolocation();
            })
            .catch(() => setText(el.status, 'MAP LOAD ERROR'));
    }

    init();
})();
