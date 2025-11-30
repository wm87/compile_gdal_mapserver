#!/usr/bin/env bash
#set -euo pipefail

#############################################
# MASTER BUILD SCRIPT (incl. GDAL-Tests)
#############################################

THREADS=6
GEOS_VERSION="3.14.1"
PROJ_VERSION="9.7.0"
GDAL_VERSION="v3.12.0"
MAPSERVER_VERSION="rel-8-4-1"
EXPAT_VERSION="R_2_7_3"

GEOS_PREFIX=/opt/geos
PROJ_PREFIX=/opt/proj
GDAL_PREFIX=/opt/gdal
MAPSERVER_PREFIX=/usr/local

BUILD_ROOT=$HOME/dev_build
PACKAGE_DIR="$BUILD_ROOT/packages"

LOGFILE=/tmp/build_master.log
mkdir -p "$(dirname "$LOGFILE")"
rm -f "$LOGFILE"

#############################################
# LOGGING
#############################################
exec > >(tee -a "$LOGFILE")
exec 2>&1
progress() { echo -e "\n\033[1;32m[INFO] $*\033[0m\n"; }
error() { echo -e "\n\033[1;31m[ERROR] $*\033[0m\n"; }

#############################################
# CLEANUP
#############################################
progress "Clean Old Builds ..."
sudo rm -rf "$GEOS_PREFIX" "$PROJ_PREFIX" "$GDAL_PREFIX"
sudo rm -rf /usr/local/bin/mapserv /usr/local/lib/libmapserver* \
	/usr/local/lib/cmake/mapserver /usr/local/include/mapserver* \
	/usr/local/share/mapserver 2>/dev/null || true
sudo rm -rf "$BUILD_ROOT"
mkdir -p "$PACKAGE_DIR"

#############################################
# BUILD DEPS
#############################################
progress "Building Dependencies ..."
sudo apt-get update
sudo apt-get -y install build-essential cmake git pkg-config wget curl unzip \
	libfreetype6-dev libfribidi-dev libharfbuzz-dev libcairo2-dev libfcgi-dev \
	librsvg2-dev libexempi-dev swig python3-dev python3-numpy \
	libfreexl-dev libxml2-dev libpq-dev librttopo-dev libzip-dev \
	libzstd-dev libgeotiff-dev libsfcgal-dev libcrypto++-dev \
	libpng-dev libgif-dev libspatialite-dev libminizip-dev sqlite3 libxerces-c-dev \
	python3-pytest python3-pip python3-scipy python3-lxml \
  python3-filelock python3-shapely python3-pyproj ccache

# Optional: Ninja + ccache for faster builds
sudo apt-get -y install ninja-build ccache
export CC="ccache gcc"
export CXX="ccache g++"

# ---------------------------
# Custom-built tools take priority
# ---------------------------
export PATH="$GEOS_PREFIX/bin:$PROJ_PREFIX/bin:$GDAL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$GEOS_PREFIX/lib:$PROJ_PREFIX/lib:$GDAL_PREFIX/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$GEOS_PREFIX/lib/pkgconfig:$PROJ_PREFIX/lib/pkgconfig:$GDAL_PREFIX/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR=""

# PROJ data
export PROJ_DATA="$PROJ_PREFIX/share/proj"

# Compiler/Linker flags
export CFLAGS="-O3 -march=native -DNDEBUG -I$GEOS_PREFIX/include -I$PROJ_PREFIX/include -I$GDAL_PREFIX/include"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$GEOS_PREFIX/lib -L$PROJ_PREFIX/lib -L$GDAL_PREFIX/lib"

#############################################
# EXPAT
#############################################
progress "Building EXPAT $EXPAT_VERSION ..."
cd "$PACKAGE_DIR"
git clone https://github.com/libexpat/libexpat.git
cd libexpat
git checkout "$EXPAT_VERSION"
cd expat
./buildconf.sh
./configure --prefix="$GDAL_PREFIX" --with-pic
make -j"$THREADS"
sudo make install
sudo ldconfig

#############################################
# GEOS
#############################################
progress "Building GEOS $GEOS_VERSION ..."
cd "$PACKAGE_DIR"
git clone https://github.com/libgeos/geos.git
cd geos
git checkout "$GEOS_VERSION"

mkdir build && cd build
cmake .. -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$GEOS_PREFIX" \
	-DCMAKE_INSTALL_RPATH="$GEOS_PREFIX/lib" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DBUILD_TESTING=OFF \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

cmake --build . -j"$THREADS"
sudo cmake --build . --target install
sudo ldconfig

#############################################
# PROJ
#############################################
progress "Building PROJ $PROJ_VERSION ..."
cd "$PACKAGE_DIR"
git clone https://github.com/OSGeo/PROJ.git
cd PROJ
git checkout "$PROJ_VERSION"

mkdir build && cd build
cmake .. -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$PROJ_PREFIX" \
	-DCMAKE_INSTALL_RPATH="$PROJ_PREFIX/lib" \
	-DCMAKE_C_COMPILER_LAUNCHER=ccache \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DPROJ_DATA="$PROJ_PREFIX/share/proj" \
	-DPROJ_DEFAULT_DB_PATH="$PROJ_PREFIX/share/proj/proj.db" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

cmake --build . -j"$THREADS"
sudo cmake --build . --target install
sudo ldconfig

# Hard-override (important!)
export PROJ_DATA="$PROJ_PREFIX/share/proj"
export LD_LIBRARY_PATH="$PROJ_PREFIX/lib:$LD_LIBRARY_PATH"
export PATH="$PROJ_PREFIX/bin:$PATH"

/opt/proj/bin/projinfo EPSG:25833 || exit 1

#############################################
# PROJ VALIDATION
#############################################
progress "Validiere PROJ…"
if ! /opt/proj/bin/projinfo EPSG:25833 >/dev/null 2>&1; then
	error "PROJ konnte EPSG:25833 nicht auflösen! Prüfe PROJ_DATA."
	exit 1
fi
progress "PROJ korrekt konfiguriert: $PROJ_DATA"

#############################################
# GDAL (with BUILD_TESTING=ON)
#############################################
progress "Building GDAL $GDAL_VERSION ..."
cd "$PACKAGE_DIR"
git clone https://github.com/OSGeo/gdal.git
cd gdal
git checkout "$GDAL_VERSION"

mkdir build && cd build
cmake .. -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$GDAL_PREFIX" \
	-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
	-DCMAKE_INSTALL_RPATH="$GEOS_PREFIX/lib;$PROJ_PREFIX/lib;$GDAL_PREFIX/lib" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DGEOS_LIBRARY="$GEOS_PREFIX/lib/libgeos_c.so" \
	-DGEOS_INCLUDE_DIR="$GEOS_PREFIX/include" \
	-DPROJ_LIBRARY="$PROJ_PREFIX/lib/libproj.so" \
	-DPROJ_INCLUDE_DIR="$PROJ_PREFIX/include" \
	-DPROJ_DATA="$PROJ_PREFIX/share/proj" \
	-DEXPAT_INCLUDE_DIR="$GDAL_PREFIX/include" \
	-DEXPAT_LIBRARY="$GDAL_PREFIX/lib/libexpat.so" \
	-DBUILD_PYTHON_BINDINGS=ON \
	-DPYTHON_EXECUTABLE=$(which python3) \
	-DGDAL_USE_PNG=ON \
	-DGDAL_USE_TIFF=ON \
	-DGDAL_USE_GEOTIFF=ON \
	-DGDAL_USE_JPEG=ON \
	-DGDAL_USE_GIF=ON \
	-DGDAL_USE_SQLITE3=ON \
	-DGDAL_USE_XERCESC=ON \
	-DBUILD_TESTING=ON \
	-DGDAL_BUILD_TESTS=ON \
	-DGDAL_BUILD_BENCHMARKS=OFF \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

cmake --build . -j"$THREADS"
sudo cmake --build . --target install
sudo ldconfig

#############################################
# GDAL TESTS
#############################################
progress "Running GDAL tests ..."
cd "$PACKAGE_DIR/gdal/build"

# Try to make pytest available
if ! python3 -c "import pytest" 2>/dev/null; then
	progress "Installing pytest for Python autotests ..."
	sudo apt-get -y install python3-pytest || {
		error "pytest installation failed; running C/C++ tests only."
		ctest -E "autotest_.*" --output-on-failure -j"$THREADS" || {
			error "GDAL C/C++ tests failed"
			exit 1
		}
		progress "GDAL C/C++ tests passed (Python autotests skipped)."
		goto_mapserver_build=true
	}
fi

if [ -z "${goto_mapserver_build:-}" ]; then
	# Optional: ensure that the GDAL Python bindings are included in the PYTHONPATH
	export PYTHONPATH="$GDAL_PREFIX/lib/python3/site-packages:$PYTHONPATH"

	# Full test suite including Python autotests
	ctest -E "(bench|benchmark|autotest.*bench)" --output-on-failure -j"$THREADS" || {
		error "GDAL tests failed"
		exit 1
	}
	progress "GDAL C/C++ tests passed (Python benchmark autotests skipped)."
fi

#############################################
# MapServer
#############################################
progress "Building MAPSERVER $MAPSERVER_VERSION ..."
cd "$PACKAGE_DIR"
git clone https://github.com/MapServer/MapServer.git
cd MapServer
git checkout "$MAPSERVER_VERSION"

mkdir build && cd build
cmake .. -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$MAPSERVER_PREFIX" \
	-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
	-DCMAKE_INSTALL_RPATH="$GEOS_PREFIX/lib;$PROJ_PREFIX/lib;$GDAL_PREFIX/lib" \
	-DCMAKE_C_COMPILER_LAUNCHER=ccache \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DGDAL_LIBRARY="$GDAL_PREFIX/lib/libgdal.so" \
	-DGDAL_INCLUDE_DIR="$GDAL_PREFIX/include" \
	-DGEOS_LIBRARY="$GEOS_PREFIX/lib/libgeos_c.so" \
	-DGEOS_INCLUDE_DIR="$GEOS_PREFIX/include" \
	-DPROJ_LIBRARY="$PROJ_PREFIX/lib/libproj.so" \
	-DPROJ_INCLUDE_DIR="$PROJ_PREFIX/include" \
	-DPROJ_DATA="$PROJ_PREFIX/share/proj" \
	-DWITH_CLIENT_WFS=ON \
	-DWITH_CLIENT_WMS=ON \
	-DWITH_AGG=ON \
	-DWITH_GD=ON \
	-DWITH_CAIRO=ON \
	-DWITH_CURL=ON \
	-DWITH_SOS=ON \
	-DWITH_PHP=ON \
	-DWITH_JAVA=OFF \
	-DWITH_PERL=ON \
	-DWITH_CSHARP=OFF \
	-DWITH_PYTHON=ON \
	-DWITH_RUBY=OFF \
	-DWITH_EXEMPI=ON \
	-DWITH_KML=ON \
	-DWITH_POSTGIS=ON \
	-DWITH_RSVG=ON \
	-DWITH_SVGCAIRO=0 \
	-DWITH_LIBXML2=ON \
	-DWITH_OGCAPI=ON \
	-DWITH_PROTOBUFC=0

cmake --build . -j"$THREADS"
sudo cmake --build . --target install
sudo ldconfig

#############################################
# FINAL CHECKS
#############################################
echo ""
echo "PROJ searchpaths and isolated:"
$PROJ_PREFIX/bin/projinfo --searchpaths
pkg-config --cflags --libs proj
echo ""
echo "✔ PROJ EPSG-Test:"
$PROJ_PREFIX/bin/projinfo EPSG:25833
echo ""
echo "✔ GEOS: $($GEOS_PREFIX/bin/geos-config --version)"
echo "✔ GDAL: $($GDAL_PREFIX/bin/ogrinfo --version)"
echo "✔ MapServer: $(/usr/local/bin/mapserv -v)"
progress "Build finished. Logfile: $LOGFILE"
