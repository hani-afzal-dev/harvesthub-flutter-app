# Changelog

All notable changes to the **HarvestHub** project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0-demo] - 2026-11-07

### Added
- **AI Crop Doctor**: Instant plant disease identification and organic treatment recommendations using Google Gemini Vision.
- **AI Voice-Powered Product Listing**: Hands-free voice listing support for rural farmers with Roman Urdu & Urdu speech transcription.
- **Smart Basket & Gemini Shopping Assistant**: Budget-conscious AI basket recommendations tailored to family meal planning.
- **Farmer Producer Hub**: Comprehensive product listing, live stock updates, order dispatch status, and pickup slot configuration.
- **Customer Marketplace**: Geolocation-aware fresh produce catalog, filter by categories, transparent pricing, and instant checkout.
- **Real-Time Push Relay**: Cloudflare Worker push relay and FCM background handlers without requiring Firebase Blaze plan.
- **Automated Testing Suite**: 146 unit, service, and widget test cases covering models, business logic, and UI interactions.

### Changed
- Refactored state architecture to Riverpod 2.x code generation with reactive streams.
- Optimized asset compression and local SQLite database caching for low-bandwidth rural connectivity.

---

## [0.9.0] - 2026-10-31

### Added
- Complete automated Firestore backup workflow (`.github/workflows/firestore-backup.yml`).
- Developer seed scripts and database recovery utilities in `tools/`.
- System architecture, Firestore security rules documentation, and deployment guides in `docs/`.
