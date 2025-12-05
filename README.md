# Master Build Skripte für Geospatial Libraries

Dieses Repository enthält **zwei Build-Skripte** für Geospatial Libraries (EXPAT, GEOS, PROJ, GDAL, MapServer) auf Linux-Systemen:

1. **[`dev_GDAL_Mapserver.sh`](https://github.com/libyourrepo/dev_GDAL_Mapserver.sh)** – Entwicklerversion: baut die neuesten Commits aus den Git-Repositories.
2. **[`stable_GDAL_Mapserver.sh`](https://github.com/libyourrepo/stable_GDAL_Mapserver.sh)** – Stabile Version: baut definierte stabile Releases der Bibliotheken.

Beide Skripte richten isolierte Entwicklungsumgebungen ein, bauen die Komponenten aus den Quellen und führen Tests durch.

---

## Übersicht

* **Sprache:** Bash
* **Build-System:** CMake + Ninja
* **Parallelisierung:** konfigurierbar via `THREADS` (Standard: 6)
* **Logging:** `/tmp/build_master.log`
* **Installationspfade (isoliert):**

  * `GEOS_PREFIX=/opt/geos`
  * `PROJ_PREFIX=/opt/proj`
  * `GDAL_PREFIX=/opt/gdal`
  * `MAPSERVER_PREFIX=/usr/local`

---

## Skript 1 – `dev_GDAL_Mapserver.sh` (Entwicklerversion)

* Git-Repositories:

  * [EXPAT](https://github.com/libexpat/libexpat.git) (main)
  * [GEOS](https://github.com/libgeos/geos.git) (main)
  * [PROJ](https://github.com/OSGeo/PROJ.git) (main)
  * [GDAL](https://github.com/OSGeo/gdal.git) (main)
  * [MapServer](https://github.com/MapServer/MapServer.git) (main)

* Build-Reihenfolge:

  1. EXPAT
  2. GEOS
  3. PROJ (inkl. EPSG-Validierung)
  4. GDAL (mit BUILD_TESTING=ON und Python-Bindings)
  5. GDAL Tests
  6. MapServer
  7. Endgültige Versions- und EPSG-Checks

---

## Skript 2 – `stable_GDAL_Mapserver.sh` (Stabile Versionen)

* Definierte Versionen:

  * EXPAT: `R_2_7_3`
  * GEOS: `3.14.1`
  * PROJ: `9.7.1`
  * GDAL: `v3.12.0`
  * MapServer: `rel-8-6-0`

* Git-Repositories:

  * [EXPAT](https://github.com/libexpat/libexpat.git) (Checkout: `R_2_7_3`)
  * [GEOS](https://github.com/libgeos/geos.git) (Checkout: `3.14.1`)
  * [PROJ](https://github.com/OSGeo/PROJ.git) (Checkout: `9.7.1`)
  * [GDAL](https://github.com/OSGeo/gdal.git) (Checkout: `v3.12.0`)
  * [MapServer](https://github.com/MapServer/MapServer.git) (Checkout: `rel-8-6-0`)

* Build-Reihenfolge identisch mit Entwicklerversion, inkl. Tests und finalen Checks.

---

## System-Abhängigkeiten (für beide Skripte, Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake git pkg-config wget curl unzip \
 libfreetype6-dev libfribidi-dev libharfbuzz-dev libcairo2-dev libfcgi-dev \
 librsvg2-dev libexempi-dev swig python3-dev python3-numpy \
 libfreexl-dev libxml2-dev libpq-dev librttopo-dev libzip-dev \
 libzstd-dev libgeotiff-dev libsfcgal-dev libcrypto++-dev \
 libpng-dev libgif-dev libspatialite-dev libminizip-dev sqlite3 libxerces-c-dev \
 python3-pytest python3-pip python3-scipy python3-lxml \
 python3-filelock python3-shapely python3-pyproj ccache ninja-build
```

* Compiler Wrapping für beide Builds:

```bash
export CC="ccache gcc"
export CXX="ccache g++"
```

* Umgebungsvariablen für Pfade, Library Paths und pkg-config bleiben identisch.

---

## Quickstart

```bash
# Skripte ausführbar machen
chmod +x dev_GDAL_Mapserver.sh stable_GDAL_Mapserver.sh

# Entwicklerversion bauen
./dev_GDAL_Mapserver.sh

# Stabile Version bauen
./stable_GDAL_Mapserver.sh
```

> Achtung: Löscht alte Installationen in den Prefixes GEOS, PROJ, GDAL und MapServer!
>
> Optional: Anpassung der `THREADS`-Variable für parallele Builds.

---

## Debugging & Logs

* Prüfe Versionsstände nach Installation:

```bash
$PROJ_PREFIX/bin/projinfo --version
$GEOS_PREFIX/bin/geos-config --version
$GDAL_PREFIX/bin/ogrinfo --version
/usr/local/bin/mapserv -v
```

* PROJ EPSG-Tests: `projinfo EPSG:25833` sollte aufgelöst werden
* Bei Fehlern in Python-Bindings sicherstellen, dass `PYTHONPATH` gesetzt ist
* Live-Log Überwachung:

```bash
tail -f /tmp/build_master.log
```

* Alle Build-Schritte werden in `/tmp/build_master.log` protokolliert
