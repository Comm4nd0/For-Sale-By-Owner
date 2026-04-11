/* ─────────────────────────────────────────────────────────────
   price-format.js

   Thousand-separator comma formatting for price inputs. Attach
   to any <input> and it will render commas as the user types;
   call FsboPriceFormat.strip() before sending to the API.
   ───────────────────────────────────────────────────────────── */
(function () {
    function format(value) {
        const digits = String(value).replace(/[^\d]/g, '');
        if (!digits) return '';
        return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    function strip(value) {
        return String(value || '').replace(/[^\d.]/g, '');
    }

    function attach(input) {
        if (!input || input.__fsboPriceAttached) return;
        input.__fsboPriceAttached = true;

        // Format any initial value (e.g. on the edit screen)
        if (input.value) input.value = format(input.value);

        input.addEventListener('input', (e) => {
            const el = e.target;
            const beforeLen = el.value.length;
            const caret = el.selectionStart;
            const formatted = format(el.value);
            el.value = formatted;
            // Preserve caret position relative to right edge, so the user
            // doesn't jump around while typing.
            const afterLen = formatted.length;
            const newCaret = Math.max(0, caret + (afterLen - beforeLen));
            try { el.setSelectionRange(newCaret, newCaret); } catch (_) { /* ignore */ }
        });

        input.addEventListener('blur', (e) => {
            e.target.value = format(e.target.value);
        });
    }

    // Auto-attach any input with [data-price-format]
    document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('input[data-price-format]').forEach(attach);
    });

    window.FsboPriceFormat = { attach, format, strip };
})();
