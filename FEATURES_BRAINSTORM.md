# Feature Brainstorm & Improvement Ideas

A prioritized list of features and improvements for the For Sale By Owner platform.

---

## High Priority — User-Facing Impact

### 1. Map & Location-Based Search
- **Radius/distance-based search** — let buyers search "within 5 miles of X postcode" instead of exact city/county matches
- Interactive map view (Leaflet/Mapbox) showing property pins alongside the list view
- Integrate UK postcode geocoding to power distance queries (PostGIS or a lightweight haversine filter)

### 2. Real-Time Messaging / Chat
- Replace the enquiry-reply model with a proper **real-time chat** between buyers and sellers (Django Channels + WebSockets)
- Unread message badges and in-app notifications
- Typing indicators, read receipts
- Keep the existing enquiry flow as the "first contact" and upgrade to chat after the seller responds

### 3. Push Notifications (Complete the Implementation)
- The `PushNotificationDevice` model already exists but isn't wired up
- Send FCM push notifications for: new enquiries, viewing confirmations, price drops on saved properties, new matches for saved searches
- Add notification preferences so users can control what they receive

### 4. Image Optimisation & CDN
- Auto-resize and compress uploaded images (thumbnails, medium, full-size variants)
- Serve via a CDN (CloudFront, Bunny.net) instead of Gunicorn/WhiteNoise for media
- WebP conversion for smaller file sizes
- This directly affects page load speed and mobile data usage

### 5. Viewing Scheduler / Calendar Integration
- Turn viewing requests into a proper **calendar** — sellers set availability slots, buyers pick from them
- Generate `.ics` calendar invites on confirmation
- Reduce the back-and-forth of "alternative date" messages

---

## Medium Priority — Growth & Engagement

### 6. Property Alerts for Saved Searches
- The `SavedSearch` model has `email_alerts` but no background job sends them
- Add a periodic task (Celery Beat or Django-Q) that matches new/updated listings against saved searches and emails users
- Include "instant" and "daily digest" frequency options

### 7. Virtual Tours / Video Support
- Allow sellers to upload a short walkthrough video or link to a Matterport/YouTube tour
- Embed video player in property detail page
- This is a major differentiator for FSBO — sellers can showcase properties without an agent's help

### 8. Advanced Analytics Dashboard for Sellers
- Current `/api/dashboard/stats/` is basic
- Add: views over time (chart), enquiry conversion rate, how the property ranks in search results, average time on listing, comparison to similar properties
- Show actionable tips ("Your listing has no floorplan — listings with floorplans get 40% more enquiries")

### 9. Offer Management System
- Allow buyers to submit formal offers through the platform
- Sellers can accept, reject, or counter-offer
- Track offer history and status (under negotiation, accepted, withdrawn)
- This keeps the entire sale journey within the platform

### 10. Social Sharing & SEO Improvements
- Open Graph / Twitter Card meta tags on property pages for rich social previews
- Structured data (JSON-LD) for Google rich results (property listings schema)
- One-click share to WhatsApp, Facebook, Twitter, email
- Sitemap generation for all active listings

---

## Medium Priority — Technical Improvements

### 11. Background Task Queue (Celery/Django-Q)
- Move email sending off the request/response cycle — currently emails block the API response
- Use for: email notifications, saved search matching, image processing, Stripe webhook retries
- Add Redis as a message broker (already useful for caching too)

### 12. Caching Layer
- Add Redis caching for: property list queries, similar properties, service provider lists, dashboard stats
- Cache invalidation on property updates
- API response caching with ETags for mobile app efficiency
- This will significantly reduce database load

### 13. Comprehensive Test Coverage
- Current tests are basic — expand to cover:
  - All permission edge cases (can't edit another user's property, etc.)
  - Stripe webhook event handling (mock Stripe signatures)
  - Saved search matching logic
  - Rate limiting behaviour
  - Flutter widget and integration tests (currently a TODO)
- Aim for 80%+ coverage with a CI coverage gate

### 14. API Pagination & Performance
- Standardise pagination across all endpoints (cursor-based for mobile infinite scroll)
- Add `select_related` / `prefetch_related` to prevent N+1 queries (especially property images, features)
- Database indexing on commonly filtered fields (postcode, city, price, status)

### 15. Admin Moderation Tools
- Listing approval queue with bulk actions
- Automated content checks (profanity filter, image moderation via AWS Rekognition or similar)
- Flagging system for users to report suspicious listings
- Admin notes and audit trail on listings

---

## Lower Priority — Nice to Have

### 16. Mortgage Calculator Widget
- Embed a simple mortgage calculator on property detail pages
- Input: property price, deposit %, interest rate, term
- Output: estimated monthly payment
- Links to mortgage broker service providers on the platform

### 17. Neighbourhood Information
- Pull in local area data: schools (Ofsted ratings), transport links, crime stats, council tax band
- Use public UK APIs (police.uk, Ofsted, Transport API)
- Helps buyers make decisions and keeps them on the platform longer

### 18. Document Sharing / Conveyancing Toolkit
- Secure document upload for property packs (title deeds, searches, EPC certificates)
- Pre-populated TA6/TA10 property information forms
- Progress tracker for the conveyancing process
- This supports the "without an agent" mission

### 19. Multi-Language Support
- i18n for the web frontend and Flutter app
- Start with Welsh (legal requirement for some Welsh property listings) and then expand

### 20. Accessibility Audit & Improvements
- Full WCAG 2.1 AA compliance audit
- Screen reader testing for property listings
- Keyboard navigation for all interactive elements
- High contrast mode option

### 21. Progressive Web App (PWA)
- Convert the web frontend into a PWA with offline support
- Property browsing works offline (cached listings)
- Push notifications via the web
- Reduces the gap between web and native app experience

### 22. Bulk Listing Tools
- CSV/spreadsheet import for property listings (useful for portfolio sellers or developers)
- Bulk status updates (mark multiple as sold, withdrawn)
- Duplicate listing as template

### 23. Referral / Affiliate Programme
- Referral codes for users who invite friends
- Commission tracking for service provider referrals
- Discount codes for subscription tiers

### 24. Dark Mode (Web & Mobile)
- The Flutter app has a defined colour palette — extend with a dark variant
- CSS custom properties on the web for easy theme switching
- Respect system-level dark mode preference

---

## Security & Operations

### 25. Security Hardening
- Set `DEBUG=False` in production Docker Compose (currently True)
- Restrict `CORS_ALLOW_ALL_ORIGINS` to specific domains in production
- Add rate limiting to all public endpoints (not just enquiry creation)
- Implement CSRF protection for web forms
- Add request logging and anomaly detection
- Regular dependency vulnerability scanning (Dependabot/Snyk)

### 26. Monitoring & Observability
- Error tracking (Sentry integration)
- Application performance monitoring (response times, slow queries)
- Uptime monitoring with alerting
- Structured logging (JSON format) for log aggregation
- Health check endpoints beyond Docker healthchecks

### 27. Database Backup & Recovery
- Automated daily PostgreSQL backups to object storage (S3/Backblaze B2)
- Point-in-time recovery capability
- Backup verification and restore testing
- Data export for GDPR compliance (right to data portability)

---

## Summary — Suggested Implementation Order

| Phase | Features | Theme |
|-------|----------|-------|
| **Phase 1** | Push notifications (#3), Background tasks (#11), Image optimisation (#4), Security hardening (#25) | Foundation & performance |
| **Phase 2** | Saved search alerts (#6), Seller analytics (#8), Map search (#1), SEO (#10) | Growth & discovery |
| **Phase 3** | Real-time chat (#2), Viewing scheduler (#5), Offer management (#9) | Transaction experience |
| **Phase 4** | Video tours (#7), Neighbourhood data (#17), Mortgage calculator (#16) | Content richness |
| **Phase 5** | Document sharing (#18), PWA (#21), Bulk tools (#22), Referral programme (#23) | Platform maturity |
