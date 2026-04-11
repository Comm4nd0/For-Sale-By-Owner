/* ─────────────────────────────────────────────────────────────
   map-pin.js

   Leaflet/OpenStreetMap pin-drop widget. No API key required.
   Attach to a container element; gives you a draggable marker
   whose lat/lon flow back through the onChange callback.
   ───────────────────────────────────────────────────────────── */
(function () {
    const UK_CENTER = [54.5, -2.5];
    const UK_ZOOM = 6;

    function init({ containerEl, lat, lon, onChange }) {
        if (!containerEl || typeof L === 'undefined') {
            console.warn('FsboMapPin: Leaflet not loaded or container missing');
            return null;
        }

        const initialLat = (lat != null && !isNaN(lat)) ? Number(lat) : null;
        const initialLon = (lon != null && !isNaN(lon)) ? Number(lon) : null;
        const initialCenter = (initialLat != null && initialLon != null)
            ? [initialLat, initialLon]
            : UK_CENTER;
        const initialZoom = (initialLat != null && initialLon != null) ? 15 : UK_ZOOM;

        const map = L.map(containerEl).setView(initialCenter, initialZoom);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        }).addTo(map);

        let marker = null;
        if (initialLat != null && initialLon != null) {
            marker = L.marker([initialLat, initialLon], { draggable: true }).addTo(map);
            marker.on('dragend', () => {
                const p = marker.getLatLng();
                if (onChange) onChange(p.lat, p.lng);
            });
        }

        // Click to drop / move
        map.on('click', (e) => {
            if (marker) {
                marker.setLatLng(e.latlng);
            } else {
                marker = L.marker(e.latlng, { draggable: true }).addTo(map);
                marker.on('dragend', () => {
                    const p = marker.getLatLng();
                    if (onChange) onChange(p.lat, p.lng);
                });
            }
            if (onChange) onChange(e.latlng.lat, e.latlng.lng);
        });

        function setLocation(newLat, newLon, zoom) {
            if (newLat == null || newLon == null) return;
            const latLng = [Number(newLat), Number(newLon)];
            map.setView(latLng, zoom != null ? zoom : 15);
            if (marker) {
                marker.setLatLng(latLng);
            } else {
                marker = L.marker(latLng, { draggable: true }).addTo(map);
                marker.on('dragend', () => {
                    const p = marker.getLatLng();
                    if (onChange) onChange(p.lat, p.lng);
                });
            }
        }

        return { map, setLocation };
    }

    window.FsboMapPin = { init };
})();
