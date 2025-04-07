######################################### CONFIGURATION & LIBRARIES #########################################
# Clear any lingering objects
rm(list = ls())

# Install libraries if necessary and load them into the environment
if (suppressWarnings(require("velociraptr"))==FALSE) {
    install.packages("velociraptr",repos="https://cloud.r-project.org");
    library("velociraptr");
    }

# Install libraries if necessary and load them into the environment
if (suppressWarnings(require("RPostgreSQL"))==FALSE) {
    install.packages("RPostgreSQL",repos="https://cloud.r-project.org");
    library("RPostgreSQL");
    }

# Install libraries if necessary and load them into the environment
if (suppressWarnings(require("divDyn"))==FALSE) {
    install.packages("divDyn",repos="https://cloud.r-project.org");
    library("divDyn");
    }

# Install libraries if necessary and load them into the environment
if (suppressWarnings(require("divvy"))==FALSE) {
    install.packages("divvy",repos="https://cloud.r-project.org");
    library("divvy");
    }

# Install libraries if necessary and load them into the environment
if (suppressWarnings(require("pbapply"))==FALSE) {
    install.packages("pbapply",repos="https://cloud.r-project.org");
    library("pbapply");
    }

# Install libraries if necessary and load them into the environment
if (suppressWarnings(require("terra"))==FALSE) {
    install.packages("terra",repos="https://cloud.r-project.org");
    library("terra");
    }

# Functions are camelCase. Variables and Data Structures are PascalCase
# Fields generally follow snake_case for better SQL compatibility
# Dependency functions are not embedded in master functions
# []-notation is used wherever possible, and $-notation is avoided but not prohibited.
# []-notation is slower, but is explicit about dimension and works for atomic vectors
# External packages are explicitly invoked per function with :: operator
# Explict package calls are not required in most cases, but are helpful in tutorials
# The <- operator is generally used when writing to an index (subscript) and = for all other situations

# Establish postgresql connection
# This assume that you already have a postgres instance with PostGIS installed and a database named ecos
# and that you have comparable configuration and credentials
# This could theoretically be done entirely within R, as the sf packae ports most geoprocessing functions
# from postgis entirely into R, but the benefit of doing it in postgis is because that allows me to preserve
# a stable database rather than recreating data constantly 
Driver<-dbDriver("PostgreSQL") # Establish database driver
Ecos<-dbConnect(Driver, dbname = "ecos", host = "localhost", port = 5432, user = "azaffos")
# An alternative, gdal-specific method of specifying the postgres connection credentials as above
# This is important if you want to use gdal/PostGIS layer creation options in sf::st_write() 
GDAL<-"PG:host=localhost port=5432 dbname=ecos user=azaffos"

# Change the maximum timeout to 600 seconds. This will allow you to download larger datafiles from 
# the paleobiology database.
options(timeout=600)

#############################################################################################################
########################################### OBIS DATA FUNCTIONS, GET ########################################
#############################################################################################################
# A function to download from OBIS.
# Substantially rewritten now to work with OBIS v3 API, which has implemented pagination
# No progress bar because you can just check the Postgres table
# I got a strange error that the library curl is needed, which should be part of R by default? But anyway,
# it is a simple matter to do install.packages('curl'); library(curl) if you get this message.
downloadOBIS<-function(Connection=Ecos,Taxa="Bivalvia",Size=1000,Fields="id",Continue="NONE") {
	# Verify that id is a field as it is needed to enforce pagination
	if ("id"%in%Fields!=TRUE) (Fields = c("id",Fields))
	# Collapse them into comma separate strings
	Taxa = paste(Taxa,collapse=",")
	Fields = paste(Fields,collapse=",")
	# Get the total number of occurrences currently in the database
	Query = paste0("https://api.obis.org/v3/occurrence?scientificname=",Taxa)
	Total = jsonlite::fromJSON(Query)$total
	# Added a "continue" option so if an error is thrown (sometimes there is a 502 timeout), you can
    # re-run the function by setting Continue = "last id" and it will pick up where it left off.
    # another benefit of the switch to writing each batch to postgres
    if (Continue == "NONE") {
        # Seed an initial request
	    Data = as.data.frame(jsonlite::fromJSON(paste0(Query,"&size=",Size,"&fields=",Fields))$results,stringsAsFactors=FALSE)
        SFData = sf::st_as_sf(Data,coords=c("decimalLongitude","decimalLatitude"),crs=4326)
        sf::st_write(dsn=Ecos,obj=SFData,layer=c("obis","raw"),row.names=FALSE)
        }
    else {
        Data = as.data.frame(jsonlite::fromJSON(paste0(Query,"&size=",Size,"&after=",Continue,"&fields=",Fields))$results,stringsAsFactors=FALSE)
        SFData = sf::st_as_sf(Data,coords=c("decimalLongitude","decimalLatitude"),crs=4326)
        sf::st_write(dsn=Ecos,obj=SFData,layer=c("obis","raw"),row.names=FALSE,append=TRUE)
        }
    # Pull the table for the count
    Counter = dbGetQuery(Connection,"SELECT count(id) FROM obis.raw;")
	while (Counter < Total) { # Interesting, writing as an inequality means you'd catch any new occurrences (within reason), haha
		Latest = tail(Data$id,1)
		Data = as.data.frame(jsonlite::fromJSON(paste0(Query,"&size=",Size,"&after=",Latest,"&fields=",Fields))$results,stringsAsFactors=FALSE)
		Counter = Counter + nrow(Data)
        SFData = sf::st_as_sf(Data,coords=c("decimalLongitude","decimalLatitude"),crs=4326)
        sf::st_write(dsn=Ecos,obj=SFData,layer=c("obis","raw"),row.names=FALSE,append=TRUE)
		}
    return(Sys.time())
	}

################################################ MODERN: Load Data ##########################################
# Download the data through the OBIS API
# The datasets is huge, so it will take quite some time. It used to take days, but the new method is only a few hours.
# I was assuming it was so slow before because of the data exchange rate, but actually I now suspecty the issue
# was how much RAM was being eaten up to hold the whole table in R before writing to postgres
Taxa = c("Bivalvia","Gastropoda","Anthozoa","Crinoidea","Nautiloidea","Brachiopoda","Bryozoa")
# Establish the desired set of output fields 
Fields = c("id","class","order","family","genus","species","decimalLongitude","decimalLatitude","marine")

# Drop the existing schema if it exists
# dbSendQuery(Ecos,"DROP SCHEMA IF EXISTS obis CASCADE;")
# Create a new schema
dbSendQuery(Ecos,"CREATE SCHEMA IF NOT EXISTS obis;")
# Download the data, takes maybe 16 hours
# A URL request has a 200 character limit, and our query is too complex. We therefore need to break up the request by looping through the taxa
HoloceneOBIS = downloadOBIS(Ecos,Taxa,10000,Fields) # last run on 3/26/25

# Clean up the table a bit to match standards
# Note that I use the sf/RPostgreSQL style of st_write() rather than the GDAL-style write used
# Throughout the rest of the script. This is to avoid a primary key collision. I could probably figure this
# by futzing with the layer creation options for the gdal postgis driver, but this works well enough.
dbSendQuery(Ecos,'ALTER TABLE obis.raw RENAME "geometry" TO geom;')
dbSendQuery(Ecos,"ALTER TABLE obis.raw ADD PRIMARY KEY (id);")
dbSendQuery(Ecos,"CREATE INDEX ON obis.raw USING GiST (geom);") # probably not needed since it is point data
dbSendQuery(Ecos,"VACUUM ANALYZE obis.raw;")

# Download marine ecoregions dataset
# Don't EVEN get me started on the ESRI API. If there was an equivalent to war crimes in web development, then ESRI's idea of REST would qualify.
# Its possible that the WHERE parameter of the query should be 1=1 rather than 1%3D1?? I just went with what the MEOW website provided by default.
# Having to specify a WHERE clause when you want everything is ridiculous in the first place and stems from PURE LAZINESS
# Ecoregions = sf::st_read("https://services.arcgis.com/F7DSX1DSNSiWmOqh/arcgis/rest/services/Marine_Ecoregions_Of_the_World_(MEOW)/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson")
# 2025 Note: the above arc service is theoretically running, but equivalent data is found at the new link below. No guarantees how long that link will stay good either. Took a while to find...
# Ecoregions = sf::st_read("https://data-gis.unep-wcmc.org/server/rest/services/Hosted/WCMC036_MEOW_PPOW_2007_2012/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson")
# Jesus, looks like the server for the second link is (permanently?) down now too. Why is this dataset so hard to get?
# Okay, I uploaded a copy to UAGIS AGOL as a feature layer so that we can hit it from the ESRI REST API.
# Update... it doesn't work, the layer keeps coming back empty (0 features) no matter what I do, even though you can see very clearly through the 
# AGOL client that it is not empty. I give up.
# Ecoregions = sf::st_read("https://services1.arcgis.com/Ezk9fcjSUkeadg6u/ArcGIS/rest/services/MEOW/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson")
# colnames(Ecoregions) = tolower(colnames(Ecoregions)) # This step may be redundant since it seems the LAUNDER parameter is now working properly in the latest patches
# Fuck... I just had the brilliant idea of uploading the damn thing as a geopkg to github and just pulling it from there. It's not a huge file.
# I lied... it is too large to upload to github. Just look for it on google...
Ecoregions = sf::st_read("")
sf::st_write(Ecoregions,GDAL,layer="obis.meow",layer_options=c("GEOMETRY_NAME=geom","LAUNDER=true","FID=id","SPATIAL_INDEX=GIST"))
# Forgot to fix the field name for province. Let us forever curse shapefiles and their character limits
dbSendQuery(Ecos,"ALTER TABLE obis.meow RENAME COLUMN provinc TO province;")

# This first step is to clean out the the OBIS data to only occurrences located within MEOW. This is to eliminate
# deep sea taxa (poorly represented in OBIS and VERY poorly represented in PBDB, as well as just things with
# bad or terrestrial coordinates. Probably could have made id as an FKEY to obis.raw too, but meh...
dbSendQuery(Ecos,"CREATE TABLE IF NOT EXISTS obis.shelf AS SELECT A.id,genus, province, ecoregion, A.geom FROM obis.raw AS A JOIN obis.meow AS B ON ST_Intersects(A.geom,B.geom) WHERE genus IS NOT NULL AND marine=TRUE AND type='MEOW'")
dbSendQuery(Ecos,"ALTER TABLE obis.shelf ADD PRIMARY KEY (id);")
dbSendQuery(Ecos,"CREATE INDEX ON obis.shelf USING GiST (geom);") # probably not needed since it is point data
dbSendQuery(Ecos,"VACUUM ANALYZE obis.shelf;")