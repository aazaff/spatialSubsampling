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
GDAL<- "PG:host=localhost port=5432 dbname=ecos user=azaffos"

# Change the maximum timeout to 600 seconds. This will allow you to download larger datafiles from 
# the paleobiology database.
options(timeout=600)

#############################################################################################################
################################################# PLOT FIGURES ##############################################
#############################################################################################################
# Drop the existing schema if it exists
dbSendQuery(Ecos,"DROP SCHEMA IF EXISTS figures CASCADE;")
# Create a new schema
dbSendQuery(Ecos,"CREATE SCHEMA figures;")

# Figure 1A Data
# Note that this pulls the plates rather than modern coastlines. Some may find it prettier/better to to use
# a layer of coastlines instead.
Modern = downloadPaleogeography(Age=0)
Ecoregions = sf::st_read(Ecos,query="SELECT * FROM obis.shelf;")

# Figure 1B Data
# Hirnantian biogeography
#HirnantianGeo = velociraptr::downloadPaleogeography(444)
#sf::st_write(HirnantianGeo,GDAL,layer="figures.hirnantiangeo",layer_options=c("GEOMETRY_NAME=geom","LAUNDER=true","FID=id","SPATIAL_INDEX=GIST"))

Hirnantian = velociraptr::downloadPBDB("metazoa","Hirnantian","Hirnantian")
Hirnantian = sf::st_as_sf(Hirnantian,coords=c("lng","lat"))

# Figure 1C Data
Single = sf::st_read(Ecos,query="SELECT * FROM results.single;")

# target aspect ratio for 3 maps of aspect ratio 1 is 0.68 for the whole. For example a
# full-page 8x11 page is 0.68 = x/11, or width = 7.48, height = 11
# Create a device window (quartz() for mac with single-column width and aspect ratio)
quartz(width=3.54,height=5.21)
par(mar=c(0,0,0,0),mgp=c(0,0,0),mfrow=c(3,1))
# Figure 1B plot
plot(st_as_sfc(Modern),col="grey",lty=0)
plot(st_as_sfc(Ecoregions),pch=16,lty=0,cex=0.2,col=as.factor(Ecoregions$ecoregion),add=TRUE)

# Figure 1B Plot
plot(st_as_sfc(Modern),col="grey",lty=0)
plot(st_as_sfc(Hirnantian),col=2,add=TRUE,pch=16,cex=0.3)

# Figure 1C Plot
plot(st_as_sfc(Modern),col="grey",lty=0)
plot(st_as_sfc(Single),col=4,add=TRUE,pch=16,cex=0.3)