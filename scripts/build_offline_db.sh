#!/bin/bash
set -e

echo "========================================================="
echo "  Downloading & Filtering OSM PBF Dumps"
echo "  This requires Osmosis. Sudo may be requested."
echo "========================================================="

if ! command -v osmosis &> /dev/null
then
    echo "Osmosis not found! Installing..."
    sudo apt-get update
    sudo apt-get install -y osmosis wget
fi

export JAVACMD_OPTIONS="-Xmx4G -Djava.io.tmpdir=../tmp_java"

mkdir -p osm_data
cd osm_data
mkdir -p ../tmp_java

# Order respects download sizes to provide fast initial progress
COUNTRIES=("switzerland" "belgium" "portugal" "italy" "spain" "france")

for c in "${COUNTRIES[@]}"; do
    echo "---------------------------------------------------------"
    echo "Processing $c..."
    if [ ! -f "$c.osm.pbf" ]; then
        wget -q --show-progress "https://download.geofabrik.de/europe/$c-latest.osm.pbf" -O "$c.osm.pbf"
    fi
    
    echo "Filtering $c via Osmosis (Extracting nwn/iwn trails + geometry)..."
    if [ ! -f "$c-filtered.osm" ]; then
        osmosis \
          --read-pbf "$c.osm.pbf" \
          --tf accept-relations route=hiking,foot \
          --tf accept-relations network=nwn,iwn \
          --used-way \
          --used-node \
          --write-xml "$c-filtered.osm"
    fi
done

echo "---------------------------------------------------------"
echo "Data filtering complete."
echo "Now building Application JSON..."
cd /home/clement/Documents/asso/hiking_trails
dart scripts/parse_local_xml.dart

echo "Done! The offline database is successfully generated."
