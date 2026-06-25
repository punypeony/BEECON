# Beecon

Beecon is an accessible navigation app for Bonifacio Global City (BGC), Philippines. It helps users with different mobility profiles find wheelchair-friendly routes, view accessibility hazards on a map, get AI-powered route insights via Gemini, and report community obstacles.

## How to Run

```bash
cd beecon_app
flutter pub get
flutter run -d chrome
```

Create `assets/.env` with your API keys (see below), then hot restart the app.

## API Keys

### Gemini API (AI accessibility insights)

1. Visit [Google AI Studio](https://aistudio.google.com/apikey)
2. Create an API key
3. Add to `assets/.env`:
   ```
   GEMINI_API_KEY=your_key_here
   ```

### OpenRouteService (walking route polylines)

1. Sign up at [openrouteservice.org](https://openrouteservice.org/)
2. Create an API key
3. Add to `assets/.env`:
   ```
   ORS_API_KEY=your_key_here
   ```

On **Flutter Web**, walking routes use the public [OSRM](https://project-osrm.org/) API (no key required, CORS-friendly). On mobile, ORS is used when a valid key is set; otherwise OSRM is used. Straight-line routes only appear if all routing providers fail.

## Architecture Overview

```
beecon_app/
├── lib/
│   ├── core/
│   │   ├── constants/       # App routes, asset paths
│   │   ├── providers/       # Riverpod state (origin, destination, polylines)
│   │   ├── router/          # GoRouter navigation + slide transitions
│   │   ├── services/        # GeminiService, OrsService
│   │   ├── storage/         # Hive local persistence
│   │   └── theme/           # Beecon orange branding
│   ├── features/
│   │   ├── auth/            # Splash, onboarding, profile selection
│   │   ├── home/            # BGC map, search, heatmap, emergency
│   │   ├── routing/         # Route generation, results, AI insights
│   │   ├── reports/         # Community hazard reporting
│   │   └── profile/         # Mobility profile, saved locations
│   └── main.dart
└── assets/
    ├── .env                 # API keys (not committed)
    └── images/
```

**Key flows:**
- **Home** — Dual search (origin/destination), ORS polylines on map, heatmap toggle, emergency FAB
- **Routes** — Three route options scored for accessibility; Gemini generates profile-aware insights
- **Report** — Local Hive storage for community hazard reports shown on the map
- **Profile** — Mobility profile stored in SharedPreferences affects AI insight tone

## Team Members

| Name | Role |
|------|------|
| _Add team member_ | _Role_ |
| _Add team member_ | _Role_ |
| _Add team member_ | _Role_ |

_Update this section with your team's names and roles._

## Demo Flows

1. **Wheelchair user** — Select Wheelchair profile → Origin: High Street BGC → Destination: SM Aura → Get Routes → View 3 polylines → Select Most Accessible → Read Gemini insight
2. **Senior citizen** — Submit broken elevator report at Uptown BGC → See red marker → Upvote → Community Verified badge
3. **General user** — Toggle heatmap → View BGC accessibility zones → Tap emergency shield → Copy GPS coordinates
