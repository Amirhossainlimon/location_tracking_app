# Google Maps Style Navigation Demo (Flutter)

This is an upgraded Android Flutter demo with a Google Maps-inspired interface.

## Included demo features

- Google Map with current GPS marker and periodic 10-second foreground GPS refresh.
- Search field with a small built-in list of sample places (Dhaka and Mountain View).
- Select a destination and display a route line, destination marker, distance and estimated time.
- Start/stop a simulated navigation preview; the blue location marker and camera move along the demo line.
- Map type selector: Default, Satellite, Terrain and Hybrid.
- Current-location recenter, zoom in and zoom out controls.
- GPS permission/error handling.

## Important demo limitations

- Search uses a built-in sample-place list. It is not live Google Places autocomplete.
- The displayed route is a straight interpolated demo line, not a real road route. The ETA is an estimate based on 30 km/h.
- Navigation is simulated and does not provide spoken instructions, turn-by-turn road guidance, traffic or rerouting.
- Real Google Maps-style place search and road directions require enabling Google Places API (New), Routes API (or Directions API) in Google Cloud, billing, and adding the corresponding API calls.
- This is foreground GPS tracking, not background tracking.

## Setup

1. Extract the ZIP and open the `google_maps_tracker` folder in VS Code or Android Studio.
2. Keep the supplied `lib/` and `pubspec.yaml` files in the project root.
3. In `android/app/src/main/AndroidManifest.xml`, merge the permissions and Google Maps API key metadata shown in `android_setup/AndroidManifest.xml.example`. Do not replace the entire manifest; merge the entries into your existing file.
4. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your key. Enable **Maps SDK for Android** for that key in Google Cloud and configure billing/restrictions.
5. From the project root run:

```cmd
flutter clean
flutter pub get
flutter run
```

## Emulator testing

1. Start the Android emulator and open its Extended Controls (`...`) > Location.
2. Set a location and send it to the emulator. Enable Android Location and grant the app location permission.
3. To test GPS refresh, send a different emulator location and wait up to 10 seconds.
4. To test the demo destination flow, tap the search box and type `Stanford`, `Lalbagh`, `Dhaka`, or another sample place name. Select a result, then tap **Start navigation**.

## Dependencies

- Flutter / Dart 3.x
- `google_maps_flutter: ^2.14.2`
- `geolocator: ^13.0.4`

The ZIP does not replace Android Gradle files, so your existing Gradle setup remains unchanged.
