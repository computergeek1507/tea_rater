# Tea Rater

A small Flutter app for keeping a list of teas and rating each one
**up**, **middle**, or **down**. The list is stored on-device and can be
imported / exported as JSON.

Live web build: https://computergeek1507.github.io/tea_rater/

## Features

- Add, edit, and delete teas (name + optional notes)
- Single-tap rating that cycles middle → up → down → middle
- Alphabetical sort and case-insensitive search across names and notes
- Persistent storage via `shared_preferences`
- Import / export the whole list as JSON (merge or replace on import)
- Material 3 theme, blue + orange palette, light/dark follows system
- Builds for Windows, Android, and Web

## JSON format

```json
[
  { "name": "Earl Grey",  "rating": "up",     "notes": "bergamot" },
  { "name": "Genmaicha",  "rating": "middle", "notes": "" },
  { "name": "Lapsang",    "rating": "down",   "notes": "too smoky" }
]
```

`rating` must be `"up"`, `"middle"`, or `"down"`. Missing or unknown
values are treated as `middle` on import.

## Running locally

Requires Flutter 3.44+ (Dart 3.12+).

```bash
flutter pub get
flutter run -d windows     # or: -d chrome, or an attached Android device
```

On Windows, Flutter needs symlink support — enable **Developer Mode**
under *Settings → System → For developers* the first time.

## Releases

CI publishes on every push to `main` (see `.github/workflows/release.yml`):

- **Web** build deployed to GitHub Pages at the URL above
- **Android APK** uploaded as a GitHub release asset on tagged pushes
  (`v*`), and as a workflow artifact on every commit
