#!/bin/bash

echo "start import $1"
echo "convert to ru-all.o5m"
osmconvert "$1" -o=ru-all.o5m
echo "done"

echo "filter data"
osmfilter ru-all.o5m --keep="boundary= place= addr:housenumber= addr:interpolation= type=associatedStreet" -o=ru-addresses.o5m
echo "done"

echo "convert filtered data to pbf"
osmconvert ru-addresses.o5m -o=ru-addresses.pbf
echo "done"

echo "clean snapshot"
osmosis --truncate-pgsql database=osm_snapshot user=dkiselev password=123
echo "done"

echo "import into db"
osmosis --read-pbf ru-addresses.pbf --write-pgsql database=osm_snapshot user=dkiselev password=123
echo "done"

echo "cleanup tables"
psql -d osm_snapshot -c "delete from polygons;"
psql -d osm_snapshot -c "delete from buildings;"
psql -d osm_snapshot -c "delete from building_addresses;"
echo "done"

echo "create multipolygons"
psql -d osm_snapshot -f build_area.sql
echo "done"

echo "find building centroids"
psql -d osm_snapshot -f build_buildings.sql
echo "done"

echo "apply address scemas"
psql -d osm_snapshot -f carlsrue.sql
psql -d osm_snapshot -f addr_buildings.sql
echo "done"

echo "collect names"
psql -d osm_snapshot -c "delete from obj_names;"
psql -d osm_snapshot -f collect_names.sql
psql -d osm_snapshot -c "insert into obj_names select (collect_names(node.tags)).*, node.id, 'N'::character from nodes as node;"
psql -d osm_snapshot -c "insert into obj_names select (collect_names(way.tags)).*, way.id, 'W'::character from ways as way;"
psql -d osm_snapshot -c "insert into obj_names select (collect_names(rel.tags)).*, rel.id, 'R'::character from relations as rel;"
psql -d osm_snapshot -c "update obj_names set tag_lang = find_locale(name_tag);"
echo "done"

echo "delete temp files"
rm ru-all.o5m ru-addresses.o5m ru-addresses.pbf

echo "all done."
