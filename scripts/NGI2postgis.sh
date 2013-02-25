#!/bin/bash
# A script to import all Chief Directorate : Surveys and Mapping
# vector tiles into PostGIS.
#
# Tim Sutton 2009
# Gavin Fleming Dec 2010, Jan 2013
# Lines prefixed with '#' are comments.

# Drop the database if it already exists!
dropdb -p 5433 ngi50k

# Now recreate the database
createdb -p 5433 -T postgis_template ngi50k

# Install the plpgsql procedural language into Postgres
# This is required before we can install the PostGIS database extensions
#createlang plpgsql ngi50k

# Install the PostGIS extention. Note you may need to adjust the path
# to lwpostgis.sql if you are using a different version of linux
#psql ngi50k < /usr/share/postgresql/8.4/contrib/postgis-1.5/postgis.sql

# Install the PostGIS spatial reference system tables.
# Once again, you may need to adjust for your system
#psql ngi50k < /usr/share/postgresql/8.4/contrib/postgis-1.5/spatial_ref_sys.sql

# We assume you have a directory containing many subdirectories labeled
# after a Degree Square e.g. 2218, 2219 etc directories.
# First we will find all shapefiles within those directores and then
# loop through the resulting list of shapefile names. The list will be
# something like this:
#./3229/3229_VEGETATION_POINT_2006_04.shp
#./3229/3229_WATER_SOURCE_POINT_2006_04.shp
#./3317/3317BB_3318AA_ARTIFICIAL_SURFACE_AREA_2006_06.shp
# etc.

# As you can see there are sometimes shp files that cover more than
# one grid square, which we will account for in our script below.

MYSTART=`date`

# We will use this file (commandlog.txt) to keep a
# reproducable list of every command that was run to import data
echo "" > commandlog.txt

for MYPATH in `find . -name *.shp`

do
  # Print the name of the file we are currently working on to screen
  echo $MYPATH

  # Get the name of the file without its directory and without its .shp
  # extension. The will change e.g. ./3229/3229_VEGETATION_POINT_2006_04.shp
  # to 3229_VEGETATION_POINT_2006_04 and store it in variable 'FILE'
  FILE=`basename $MYPATH .shp`

  # Now we want to get rid of the Degree cell number prefix from the front
  # of the file name so that 3229_VEGETATION_POINT_2006_04 will be
  # changed to VEGETATION_POINT_2006_04. The line below also accounts for
  # when we have a 'two cell' layer like: 3317BB_3318AA_ARTIFICIAL_SURFACE_AREA_2006_06
  # which afterwards will become ARTIFICIAL_SURFACE_AREA_2006_06.
  # The result of this step is stored in the variable 'LAYER'
  LAYER=`echo $FILE | sed 's/^[0-9]*..\_//g' | sed 's/^[0-9]*..\_//g' | sed 's/^[0-9]*\_//g'`

  # Now lets get rid of that date at the end. So ARTIFICIAL_SURFACE_AREA_2006_06
  # will become ARTIFICIAL_SURFACE_AREA. This again be stored as 'LAYER'
  # replacing the old value.
  LAYER=`echo $LAYER | sed 's/\_....\_..$//g'`

  # Now lets get rid of any underscores and save the result again in 'LAYER'
  # So ARTIFICIAL_SURFACE_AREA will become ARTIFICIALSURFACEAREA.
  LAYER=`echo $LAYER | sed 's/\_//g'`

  # If there are still any numbers left in our name (there shouldnt be)
  # lets get rid of them.
  LAYER=`echo $LAYER | sed 's/[0-9]//g'`

  # Now lets convert the name to lower case so that ARTIFICIALSURFACEAREA
  # becomes artificialsurfacearea. Once again its stored as 'LAYER'
  LAYER=`echo $LAYER | tr "[:upper:]" "[:lower:]"`

  # Now find out the directory name from the original file name. So
  # if we had ./3229/3229_VEGETATION_POINT_2006_04.shp to start with,
  # DIR will store ./3229/ afterwards.
  DIR=`echo $MYPATH | sed 's/....\_.*$//g'`

  # The next three lines just print the result of the above steps to
  # the screen for information...
  echo "File : $FILE"
  echo "Layer: $LAYER"
  echo "Dir  : $DIR"

  # Now we want to see if our database already has a table for our layer
  # (e.g. artificialsurfacearea)
  if test `echo "\d" | psql -p 5433 ngi50k | grep -o "${LAYER} "`
  then
    # Ok we found the table already exists so the '-a' option in
    # shp2pgsql tells shp2pgsql to append the data to the existing table
    # -s 4326 tells it the CRS should be lat long / wgs84
    # -W UTF-8 tells it to load text data as UTF-8 rather than unicode
    echo "Database table exists, appending..."
    shp2pgsql -a -s 4326 -D -W LATIN1 $MYPATH $LAYER 2>>/tmp/ngiloaders2plog | psql -p 5433 -q -d ngi50k  >>/tmp/ngiloaderpglog 2>&1
    echo "shp2pgsql -a -s 4326 -D -W LATIN1 $MYPATH $LAYER 2>/tmp/ngiloaderlog | psql -p 5433 -q -d ngi50k  >/dev/null 2>&1" >> commandlog.txt
  else
    # In the alternate case, the table doesnt already exist so we rather create
    # a new table named after the layer using '-c' with a spatial index '-I'
    echo "Database table does not exist, creating..."
    shp2pgsql -I -c -s 4326 -D -W LATIN1 $MYPATH $LAYER 2>>/tmp/ngiloaders2plog | psql -p 5433 -q -d ngi50k  >>/tmp/ngiloaderpglog 2>&1
    echo "shp2pgsql -I -c -s 4326 -D -W LATIN1 $MYPATH $LAYER 2>/tmp/ngiloaders2plog | psql -p 5433 -q -d ngi50k  >/dev/null 2>&1" >> commandlog.txt
  fi
  # Ok now we loop on through to the next layer until we are all done...
done

MYEND=`date`

echo "Import started at ${MYSTART}"
echo "Import ended at   ${MYEND}"
