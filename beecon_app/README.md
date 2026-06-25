# Beecon

Accessible navigation for Bonifacio Global City (BGC), Philippines — wheelchair-friendly routes, AI insights, community hazard reporting, and an interactive accessibility map.

## Quick Start

```bash
cd beecon_app
flutter pub get
```

Create `assets/.env`:

```env
GEMINI_API_KEY=your_key_here
ORS_API_KEY=your_key_here
```

```bash
flutter run -d chrome
```

Hot **restart** after changing `.env`.

## Documentation

**Full project documentation:** [DOCUMENTATION.md](./DOCUMENTATION.md)

Covers planning (including **Bob IBM** for project structure), architecture, every feature, state management, APIs, setup, demo flows, and troubleshooting.

## Highlights

| Feature | Description |
|---------|-------------|
| Map search | Dual origin/destination bars with 20 BGC landmarks |
| Routing | 3 walking polylines (OSRM on web) + accessibility-scored route cards |
| AI insights | Gemini 2.0 Flash, profile-aware route assessments |
| Reports | Tap map to pin location → submit hazard to local Hive storage |
| Profiles | Wheelchair, Senior, Stroller, Luggage, Injury, General |

## API Keys

| Service | Purpose | Sign up |
|---------|---------|---------|
| Gemini | AI accessibility insights | [Google AI Studio](https://aistudio.google.com/apikey) |
| OpenRouteService | Mobile walking polylines (optional on web) | [openrouteservice.org](https://openrouteservice.org/) |

On Flutter Web, **OSRM** provides routing without a key. ORS is used on mobile when configured.

## License

Private / academic project — update as needed.
