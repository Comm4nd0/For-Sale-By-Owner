/* ─────────────────────────────────────────────────────────────
   postcode-lookup.js

   Thin wrapper around /api/postcode-lookup/<postcode>/ (which
   proxies postcodes.io). Used on the Phase 1 create form and
   the Phase 2 "Complete your listing" screen.

   IMPORTANT: postcodes.io does NOT return a list of addresses
   for a postcode — it only returns the postcode's centroid
   (lat/lon) and its admin district/region. The user still types
   the house number / street name. That matches the plan; a
   paid provider would be needed for full address lists.
   ───────────────────────────────────────────────────────────── */
(function () {
    function normalize(value) {
        return String(value || '').replace(/\s+/g, '').toUpperCase();
    }

    async function lookup(postcode) {
        const normalized = normalize(postcode);
        if (!normalized) throw new Error('Postcode required');
        const res = await fetch(`/api/postcode-lookup/${encodeURIComponent(normalized)}/`);
        if (!res.ok) {
            if (res.status === 404) throw new Error('Postcode not found');
            throw new Error('Postcode lookup unavailable — please try again');
        }
        return res.json();
    }

    function attach({ inputEl, buttonEl, hintEl, onResult, cityEl, countyEl, latEl, lonEl }) {
        if (!inputEl) return;

        async function run() {
            if (!inputEl.value.trim()) return;
            if (hintEl) { hintEl.textContent = 'Looking up…'; hintEl.style.color = '#8FA3A8'; }
            try {
                const result = await lookup(inputEl.value);
                if (hintEl) {
                    hintEl.textContent = `Found: ${result.admin_district || ''}${result.region ? ', ' + result.region : ''}. You can still type the street name.`;
                    hintEl.style.color = '#19747E';
                }
                if (cityEl && result.admin_district) cityEl.value = result.admin_district;
                if (countyEl && (result.admin_county || result.region)) {
                    countyEl.value = result.admin_county || result.region;
                }
                if (latEl && result.latitude != null) latEl.value = result.latitude;
                if (lonEl && result.longitude != null) lonEl.value = result.longitude;
                if (typeof onResult === 'function') onResult(result);
            } catch (err) {
                if (hintEl) {
                    hintEl.textContent = err.message || 'Lookup failed';
                    hintEl.style.color = '#B03A2E';
                }
                if (typeof onResult === 'function') onResult(null);
            }
        }

        if (buttonEl) buttonEl.addEventListener('click', run);
        inputEl.addEventListener('blur', () => {
            // Auto-run when the user tabs/clicks away, but only if they
            // typed something that looks like a UK postcode.
            const value = inputEl.value.trim();
            if (/^[A-Za-z]{1,2}\d[\w\d]?\s*\d[A-Za-z]{2}$/.test(value)) run();
        });
    }

    window.FsboPostcodeLookup = { attach, lookup, normalize };
})();
