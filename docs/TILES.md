# Building offline raster MBTiles for Trail

Trail's Phase 4 map viewer reads `.mbtiles` (SQLite-backed raster tile
archives) from the app's documents directory. Build one on your PC,
push it to the phone, install via **Settings → Regions → Install**, and
then set it as active. The viewer switches to offline tiles
automatically; uninstall the region (or clear "active") to fall back to
online OpenStreetMap.

This doc is the one-time build pipeline — nothing here runs on the
phone.

## Why raster, not vector

Raster is a brute-force choice: bigger files, no dynamic styling, but
**zero runtime cost** beyond blitting a PNG. Vector MBTiles would
require a live renderer (MapLibre) that adds an order of magnitude of
complexity and battery draw for a history viewer you glance at a few
times a week. Raster is the right call for this app.

## Tooling options

### Option A — `tilemaker` from a Geofabrik extract (recommended)

1. **Download the extract** you want from Geofabrik. For the UK:
   ```bash
   wget https://download.geofabrik.de/europe/great-britain-latest.osm.pbf
   ```

2. **Install tilemaker.** On macOS:
   ```bash
   brew install tilemaker
   ```
   On Debian/Ubuntu:
   ```bash
   sudo apt install tilemaker
   ```

3. **Render to vector MBTiles first** using the default OpenMapTiles
   config that ships with tilemaker:
   ```bash
   tilemaker \
     --input great-britain-latest.osm.pbf \
     --output uk.mbtiles \
     --config /usr/local/share/tilemaker/config-openmaptiles.json \
     --process /usr/local/share/tilemaker/process-openmaptiles.lua
   ```
   (Adjust paths — `brew --prefix tilemaker` on macOS,
   `/usr/share/tilemaker/` on apt-based distros.)

4. **Rasterise the vector MBTiles.** tilemaker emits vector tiles, but
   Trail needs raster. Use `tippecanoe` + `mbutil` OR a one-shot helper
   like `mbtiles-render` (any renderer that takes a style JSON + vector
   MBTiles and spits out a raster MBTiles).

   Simplest modern approach: run
   [`planetiler`](https://github.com/onthegomap/planetiler) to produce
   vector tiles, then
   [`martin-raster-mbtiles`](https://github.com/maplibre/martin) or
   `mbview` to pre-bake rasters.

   If this sounds heavy, **Option B is lighter for small regions.**

### Option B — pre-built raster MBTiles from a service

For small-to-mid regions, the easiest path is often to download
pre-built raster MBTiles from a tile provider:

- **MapTiler Data** (free tier available for small countries).
- **Protomaps** downloads + on-the-fly raster rendering.
- Any OpenStreetMap mirror that exposes a z/x/y raster endpoint — scrape
  with a 2-zoom-level cap and pack with
  [`mbutil`](https://github.com/mapbox/mbutil).

Whatever the source, the output must be a **raster** (PNG or JPEG)
MBTiles.

### Option C — tiny dev MBTiles

For development / smoke testing:

```bash
# London-sized test tile, ~20 MB
curl -L https://example.com/london.mbtiles -o london.mbtiles
```

Swap in any public test MBTiles.

## Size budget

| Region            | Raster MBTiles | Notes                          |
|-------------------|---------------:|--------------------------------|
| Greater London    |       40-80 MB | z6-z14, fine for dev           |
| Great Britain     |     200-600 MB | PLAN.md target                 |
| Continental US    |       1-3 GB   | only if you really need it     |

The viewer will open files of any size — the bottleneck is phone
storage, not the renderer.

## Push to phone

```bash
adb push uk.mbtiles /sdcard/Download/uk.mbtiles
```

Then on the phone: **Settings → Regions → Install**, pick
`uk.mbtiles` from Downloads. Trail copies the file into its app
documents dir (`/data/data/com.dazeddingo.trail/files/mbtiles/`) so it
survives the SAF URI going stale.

Once installed, the Regions screen shows the file with its size. Tap
the row (or the popup menu) to **Set as active**. The home-screen
trail map and the full map screen both switch to offline tiles
immediately.

## Uninstall survival

MBTiles regions live in the app's documents dir and are explicitly
**excluded** from Android auto-backup in `android/app/src/main/res/xml/backup_rules.xml`
(they'd blow the 25MB per-app backup quota on Google Drive). Plan to
re-sideload after an uninstall-restore.

The encrypted DB (pings, contacts) still survives uninstall-restore
via the passphrase-mode backup path — see the main `PLAN.md`.

## Troubleshooting

**"Tile not found" flickers on zoom.** The MBTiles package only
contains the zoom levels you built. If you rendered z6-z14 and the
viewer tries z15, tiles 404. flutter_map handles this gracefully
(blank grid with polyline still drawn) — increase the zoom cap in the
build if you want sharper close-ups at the cost of much larger files.

**File picker only shows "any file".** `FilePicker.pickFiles` uses
Android SAF; there's no registered MIME for `.mbtiles`. Trail filters
to `.mbtiles` extensions after the pick, so picking the wrong file
surfaces a clean "Pick a .mbtiles file" SnackBar rather than an
install error.

**Active region disappears after OS upgrade.** Trail detects a missing
file on every load and clears the active pref automatically, so the
viewer falls back to online OSM without user action.
