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

## New Ideas — Not Yet Covered Above

### 28. Seller Onboarding Wizard & Listing Quality Score
- Guided step-by-step wizard for first-time sellers: "List your property in 10 minutes"
- Listing quality/completeness score (e.g. "Your listing is 65% complete — add a floorplan and EPC to reach 90%")
- Contextual tips at each step ("Properties with 10+ photos get 3x more enquiries")
- Pre-listing checklist: EPC arranged, photos taken, price researched, legal pack started
- This directly addresses the biggest barrier for FSBO sellers — not knowing where to start

### 29. Price Comparison & Valuation Tool
- "What's my home worth?" tool using Land Registry sold prices data (freely available via HM Land Registry PPD)
- Show comparable recent sales in the same postcode/area
- Price-per-square-foot analysis against local averages
- Suggest a listing price range based on comparables
- Helps sellers price realistically without an estate agent's valuation, reducing stale overpriced listings

### 30. Buyer Verification & Proof of Funds
- Allow buyers to verify their identity and financial position before making offers
- "Verified buyer" badge (mortgage agreement in principle uploaded, or proof of funds for cash buyers)
- Sellers can filter offers/enquiries by verified buyers
- Reduces time-wasters — a major pain point for private sellers
- Could integrate with Open Banking APIs for lightweight bank statement verification

### 31. Conveyancing Progress Tracker
- Visual timeline/kanban for the post-offer sale process: offer accepted → solicitors instructed → searches ordered → enquiries raised → exchange → completion
- Both buyer and seller see the same shared view with status updates
- Automated nudges when a step has been stuck for too long ("Searches have been pending for 3 weeks — chase your solicitor")
- This is where most FSBO sellers feel lost — keeping the sale on track without an agent

### 32. AI-Powered Listing Description Generator
- Seller enters key property details and the tool generates a professional property description
- Multiple tone options: "estate agent style", "casual & friendly", "factual & concise"
- Highlight nearby amenities, transport links, and school catchments automatically from postcode data
- Spelling/grammar check on manually written descriptions
- Removes one of the biggest friction points: writing a compelling listing without professional help

### 33. Comparable Listings / "Similar Properties" Section
- Show similar properties on each listing page (same area, similar price/size)
- "Your property vs the competition" view in the seller dashboard
- Helps buyers discover more listings and increases time on site
- Helps sellers understand their market position

### 34. Email Alerts for Seller Activity Reminders
- Nudge sellers who haven't logged in for 7/14/30 days ("You have 3 unread messages")
- Alert when a listing goes stale: "Your property has been listed for 60 days — consider updating photos or adjusting the price"
- Weekly seller digest: views this week, new saves, enquiries, how you compare to similar listings
- Re-engagement campaigns to reduce listing abandonment

### 35. Stamp Duty Calculator
- UK Stamp Duty Land Tax calculator on property detail pages
- Handle the different rates: standard, first-time buyer relief, additional property surcharge, Wales LTT, Scotland LBTT
- Show the total purchase cost breakdown (price + stamp duty + estimated legal fees + survey costs)
- Complements the existing mortgage calculator and helps buyers understand true costs

### 36. Property History & Title Insights
- Pull data from Land Registry to show previous sale prices and dates for the property
- Display how long the property has been on the market
- Show price changes (already tracked internally — surface this to buyers)
- Transparency builds trust, which is especially important for FSBO where there's no agent brand reputation

### 37. Open House / Group Viewing Events
- Let sellers create "open house" events visible on the listing (date, time window)
- Buyers can RSVP to attend
- Reduces the burden of scheduling individual viewings
- Calendar integration with the existing viewing slot system
- Popular in the US FSBO market and starting to gain traction in the UK

### 38. QR Code Property Flyers
- Auto-generate a printable PDF flyer for each listing with key details, photos, and a QR code linking to the online listing
- Sellers can print and post in the window, distribute to neighbours, or put on community boards
- Bridges offline and online marketing — important for FSBO sellers who don't have agent "For Sale" boards with QR codes

### 39. Solicitor / Conveyancer Matching
- When a sale is agreed, prompt both parties to find a solicitor via the service provider marketplace
- "Get 3 quotes" flow where matched conveyancers can bid for the work
- Integration with the conveyancing progress tracker (#31)
- Revenue opportunity: lead generation fees from solicitors
- Ties the service marketplace directly into the transaction workflow

### 40. Neighbourhood Reviews by Residents
- Let verified local residents leave area reviews (not just property reviews)
- Categories: community feel, noise levels, parking, local shops, safety, schools
- Aggregate into a neighbourhood score
- User-generated content that's unique to the platform and hard for Rightmove/Zoopla to replicate
- Builds a community dimension beyond just transactions

### 41. "For Sale" Board Ordering Service
- Partner with a signage company to let sellers order physical "For Sale" boards
- Pre-printed with the for-sale-by-owner.co.uk domain and property QR code
- Significant credibility boost for FSBO sellers — a board outside the house signals a real sale
- Revenue opportunity through markup or referral commission

### 42. Accessibility & EPC Energy Improvement Suggestions
- Parse the EPC rating and suggest energy improvements with estimated costs and savings
- Link to relevant service providers on the platform (insulation installers, boiler engineers, solar panel fitters)
- With UK EPC regulations tightening, this is increasingly relevant
- Adds genuine value beyond just listing the property

### 43. Buyer Affordability Profile
- Buyers can create a financial profile: budget, deposit amount, mortgage approved amount
- Platform surfaces only properties within their realistic budget
- Sellers see at a glance whether an enquiring buyer can actually afford their property
- Reduces wasted viewings and improves the quality of leads for sellers

### 44. Two-Factor Authentication (2FA)
- Add TOTP-based 2FA (Google Authenticator / Authy) for user accounts
- SMS verification as a fallback option
- Critical for a platform handling property transactions and financial information
- Builds trust and meets user expectations for security on a high-value platform

### 45. Community Forum / Knowledge Base
- Q&A forum or wiki covering common FSBO topics: "How do I handle a survey?", "What is exchange of contracts?", "Do I need an EPC?"
- Seller success stories and case studies
- Positions the platform as the go-to resource for private sellers, not just a listings site
- SEO goldmine — long-tail searches like "how to sell my house without an estate agent"
- Could eventually host webinars or video guides

---

## Summary — Suggested Implementation Order

| Phase | Features | Theme |
|-------|----------|-------|
| **Phase 1** | Push notifications (#3), Background tasks (#11), Image optimisation (#4), Security hardening (#25), 2FA (#44) | Foundation, performance & security |
| **Phase 2** | Saved search alerts (#6), Seller analytics (#8), Map search (#1), SEO (#10), Seller onboarding wizard (#28) | Growth & discovery |
| **Phase 3** | Real-time chat (#2), Viewing scheduler (#5), Offer management (#9), Buyer verification (#30) | Transaction experience |
| **Phase 4** | Video tours (#7), Neighbourhood data (#17), Mortgage calculator (#16), Stamp duty calculator (#35), AI listing generator (#32) | Content richness & seller tools |
| **Phase 5** | Document sharing (#18), Conveyancing tracker (#31), Solicitor matching (#39), Price comparison tool (#29) | Full transaction support |
| **Phase 6** | PWA (#21), Bulk tools (#22), QR flyers (#38), "For Sale" boards (#41), Community forum (#45) | Platform maturity & offline reach |
| **Phase 7** | Neighbourhood reviews (#40), Buyer affordability (#43), Similar properties (#33), Seller re-engagement (#34), EPC suggestions (#42), Open house events (#37) | Engagement & differentiation |
