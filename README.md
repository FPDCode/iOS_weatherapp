# Weather App for iOS

A comprehensive, beautifully designed weather app for iPhone, iPad, and Apple Watch — built with SwiftUI and Metal shaders.

## Screenshots

The app features a dynamic Metal shader sky that adapts to time of day and weather conditions, with procedural clouds, rain particles, and a sun/moon arc tracking system.

## Features

### Now Tab
- **Dynamic Sky Header** — Real-time Metal shader rendering with atmospheric scattering, procedural FBM clouds, rain/snow particles, sun bloom, moon glow, and twinkling stars
- **Sun/Moon Arc** — Dotted progress bar tracking the sun during the day and moon at night across an elliptical arc
- **Smart Alerts** — AI-powered weather warnings (pollen, UV, visibility, wind, pressure drops, frost, storms)
- **Precipitation Timeline** — Next 2 hours with 15-minute resolution, showing both chance % and amount
- **Today's Forecast** — Morning, afternoon, evening, night phase cards
- **Hourly Forecast** — 48-hour scrollable forecast with metric picker (temp, precip, wind, UV, humidity)
- **Radar Preview** — Mini radar map with RainViewer tile overlay
- **10-Day Forecast** — Daily forecast with feel-based temperature color bars
- **Sunrise & Sunset** — Elliptical arc with progress indicator, first/last light, total daylight
- **Wind Gauge** — Compass with direction arrow, speed, gusts, Beaufort scale
- **Air Pressure** — Interactive chart with 6h/12h range selector and trend analysis
- **Air Quality & UV** — AQI index, PM2.5/PM10, UV index with tappable pollen detail
- **Cloud Cover** — Three-layer (high/mid/low) interactive charts with 6h/12h/24h range selector
- **Moon Phase** — Astronomical calculation with Canvas crescent rendering and upcoming phases

### Plan Tab
- **Morning Briefing** — Clothing suggestions, umbrella needed, sunrise/sunset
- **Weather Alerts** — Timing info ("Starting around 2 PM — in 3h")
- **Commute Weather** — Departure and return forecasts
- **Sunshine Planner** — Best sunshine windows, duration, percentage
- **Best Time For** — Activity planner (Running, Walking, Cycling, Errands) scored over next 36 hours
- **Quick Picks** — Best time for each activity at a glance
- **Comfort Level** — Dew point based comfort with clothing advice (iOS 26 on-device LLM)
- **Garden & Soil** — Soil temperature, moisture, frost risk, planting advice

### Radar Tab
- **Full Radar Map** — RainViewer radar and satellite tiles
- **Playback Controls** — Animate through past and forecast frames
- **Camera Zoom Limit** — Prevents zooming past supported tile levels

### Detail Sheets (tap any card)
Every card is tappable and opens a rich detail sheet with:
- **Interactive Charts** — Long-press + drag to scrub through data points with haptic feedback
- **24-hour trend charts** for UV, wind, pressure, precipitation
- **Health advice** and recommendations based on current levels
- **Reference scales** and educational content

Available detail sheets: AQI, UV Index, Pressure, Wind, Sunrise & Sunset, Pollen, Precipitation, Cloud Cover, Comfort Level, Garden & Soil, Moon Phase

### Live Activity & Dynamic Island
- **Rain Live Activity** — Appears on lock screen when rain is detected in the next 2 hours
- **Precipitation bars** with intensity colors and chance percentages
- **Dynamic Island** — Compact and expanded views with rain summary
- **Auto lifecycle** — Starts/updates/ends based on real precipitation data

### Widgets
5 home screen widgets:
| Widget | Size | Content |
|--------|------|---------|
| Current Conditions | Small | Temp, icon, condition, H/L |
| Hourly Forecast | Medium | Next 6 hours |
| Rain Timeline | Medium | 2-hour precipitation bars |
| Daily Forecast | Large | 5-day outlook with temp bars |
| Best Time For | Medium | Configurable activity (press & hold) |

All widgets deep-link to the relevant section in the app.

### Apple Watch App
- Current conditions with weather icon, temperature, feels-like
- 12-hour horizontal scrollable hourly forecast
- 5-day daily mini forecast
- 2-hour precipitation timeline
- Data synced from iPhone via WatchConnectivity

### Location Management
- **Multiple saved locations** with labels (Home, Work, Gym, School, Partner, Parents, Outdoors, Commute, etc.)
- **Quick switcher** in toolbar with label icons
- **Swipe to label** existing locations
- **City search** with MapKit integration

### Settings
- **Measurement System** — Imperial, Metric, UK Mixed, or Custom
- **Individual Units** — Temperature, wind speed, precipitation, pressure, visibility, time format
- **Commute Hours** — Customizable departure and return times
- **Google Calendar** — OAuth 2.0 sign-in for calendar-aware activity planning

## Technical Stack

### Architecture
- **SwiftUI** — Declarative UI across iPhone, iPad, Watch
- **Metal Shaders** — 3-layer `[[ stitchable ]]` colorEffect pipeline for sky rendering
- **MVVM** — WeatherViewModel with @Published properties
- **ActivityKit** — Live Activities and Dynamic Island
- **WidgetKit** — 5 home screen widgets + configurable AppIntent
- **WatchConnectivity** — iPhone ↔ Watch data sync
- **EventKit** — Calendar integration for activity planning
- **MapKit** — Radar tiles and city search

### Metal Shader Pipeline
1. **atmosphericSky** — Rayleigh/Mie scattering, multi-bloom sun/moon, dotted arc, star field, ground fade
2. **proceduralClouds** — FBM noise with domain warping, 3 sub-layers driven by real cloud cover data
3. **weatherParticles** — Rain streaks with parallax depth, splash effects, snow mode

### Data Sources
- **Open-Meteo Weather API** — Hourly and daily forecasts, 15-minute precipitation
- **Open-Meteo Air Quality API** — AQI, PM2.5, PM10, 6 pollen types
- **NWS Alerts API** — Official weather warnings (US)
- **RainViewer API** — Radar and satellite imagery tiles

### iOS 26 Features
- **Liquid Glass** — Adaptive glass effect on cards (fallback to ultraThinMaterial on iOS 17/18)
- **Foundation Models** — On-device LLM for personalized clothing advice (with static fallback)

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+
- Swift 5.0+

## Setup

1. Clone the repository
2. Open `WeatherApp.xcodeproj` in Xcode
3. Set your development team in Signing & Capabilities
4. Enable App Groups (`group.com.weatherapp.betterWeather`) on both main app and widget extension targets
5. Build and run

### Optional Setup
- **Google Calendar**: Create an OAuth Client ID in Google Cloud Console and configure in Settings
- **Apple Watch**: Select the WeatherWatch scheme to build and deploy to Watch

## License

Private project.
