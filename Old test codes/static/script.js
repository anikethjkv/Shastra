let map;
let bikeMarker;

function initMap() {
    // Start centered on your current city: Bengaluru
    map = L.map('map', {
        zoomControl: false, // Cleaner UI for bike dash
        attributionControl: false
    }).setView([12.9716, 77.5946], 15);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

    // Custom Icon for the Bike
    const bikeIcon = L.divIcon({
        className: 'bike-icon',
        html: '<div style="background:#0056b3; width:15px; height:15px; border-radius:50%; border:3px solid white;"></div>',
        iconSize: [20, 20]
    });

    bikeMarker = L.marker([12.9716, 77.5946], {icon: bikeIcon}).addTo(map);
}

// Call init once
initMap();

function updateDashboard() {
    fetch('/data')
        .then(res => res.json())
        .then(data => {
            // ... (your existing UI updates for speed, battery, etc.)

            // GPS Marker Update
            if (data.gps_status && data.lat && data.lon) {
                const newPos = [data.lat, data.lon];
                bikeMarker.setLatLng(newPos);
                map.panTo(newPos); // Keeps bike centered
            }
        });
}
setInterval(updateDashboard, 100);
