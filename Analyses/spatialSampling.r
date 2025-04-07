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
############################################# SIMULATE FOSSIL RECORD ########################################
#############################################################################################################
# This function takes occurrence data from OBIS (pre-loaded into a PostgreSQL database) and spatially subsamples
# it to create a spatially heterogeneous record that is highly analagous to the spatial sampling patterns in the
# Paleobiology Database. 
# Specifically, a number of LOCI (concentrated areas of high sampling) are selected, with sampling intensity
# decreasing further away from these LOCI.

# CONNECTION - PostgreSQL connection data, see above scripts related to downloading and loading data.
# METHOD/LOCI - Uses either a FIXED number of LOCI (areas of high sampling concentration) or a RANDOM number of
# 1:LOCI.
# BASE/FACTOR - The level of sampling for highly-sampled is set by the value of BASE. For example, sampling at a rate of 50% 
# would require a BASE of 0.5, 1% would be 0.01 etc. The sampling rate is set to reduce by a fixed FACTOR when moving away
# from the region of highest sampling. For example, setting the FACTOR equal to 2 would reduce the sampling rate by half.
# Setting FACTOR to 10 would decrease sampling by an order of magnitude, etc.

# My initial run assumed 4 basins using the Hirnantian as a guide, but that is overly conservative. An examination of the fossil record
# generally shows 4 or MORE basins of heavy concentration. Were I to re-run this, I would recommend upping this number to six, or,
# even better, actually going through the paleo maps and calculating ing the average number of fossil-rich basins per stage - cf., Philippi et al. 2025.
# Another wrinkle is that the North Sea (Baltic/UK) is so densely sampled that a cluster shows up there pretty much all the time even when it is
# sampled at 0.0001. But, it could be this mimics the fossil record witch certain very consistently sampled basins?

# See the future into the present, see my past lives in the distance
# Try to guess now what's going on and the band begins to play
# Don't you see my condition, conviction
createRecord = function (Connection=Ecos,Loci=6,Method="Fixed",Base=0.1,Factor=10,Target="obis.shelf") {
    MEOW = dbGetQuery(Connection,"SELECT ecoregion,province FROM obis.meow WHERE type='MEOW';")
    # Note that the Sequential option is underdeveloped, but with some additional hyperparameterization
    # it would allow simulation of spatial AND temporal autocorrelation of loci - which is more realistic
    Ecoregions = switch(Method,
        "Fixed"=sample(MEOW$ecoregion,Loci,replace=FALSE),
        "Random"=sample(MEOW$ecoregion,sample(1:Loci,1),replace=FALSE),
        "Sequential"=unique(MEOW$ecoregion)[Loci]
        )
    Provinces = subset(MEOW,MEOW$ecoregion%in%Ecoregions)$province
    # Note, I do most of the selects and filtering in PostgreSQL because it is SUBSTANTIALLY faster than loading into R
    Local = dbGetQuery(Connection,paste0("SELECT id FROM ",Target," WHERE ecoregion IN (",paste0("'", Ecoregions, "'",collapse=","),");"))
    Near = dbGetQuery(Connection,paste0("SELECT id FROM ",Target," WHERE ecoregion NOT IN (",paste0("'", Ecoregions, "'",collapse=","),") AND province IN (",paste0("'", Provinces, "'",collapse=","),");"))
    Far = dbGetQuery(Connection,paste0("SELECT id FROM ",Target," WHERE province NOT IN (",paste0("'", Provinces, "'",collapse=","),");"))
    Local = sample(Local[,"id"],ceiling(nrow(Local)*Base),replace=FALSE)
    Near = sample(Near[,"id"],ceiling(nrow(Near)*(Base/Factor)),replace=FALSE)
    Far = sample(Far[,"id"],ceiling(nrow(Far)*(Base/Factor/Factor/Factor)),replace=FALSE)
    Ids = c(Local,Near,Far)
    # Data = sf::st_read(Connection,query=paste0("SELECT id,genus,geom FROM ",Target," WHERE id IN (",paste0("'", Ids, "'",collapse=","),");"))
    # Actually much faster for it NOT to be brought in as a spatial object
    Data = dbGetQuery(Connection,paste0("SELECT id,genus,st_x(geom) AS lng,st_y(geom) AS lat FROM ",Target," WHERE id IN (",paste0("'", Ids, "'",collapse=","),");"))
    return(Data)
    }

# Set to 100 to match quotaN used in sdSumry
calcTraditional = function(Data,Limit=100,Iterations=100) {
    Raw = length(unique(Data$genus))
    Rarefaction = array(NA,dim=Iterations)
    for (i in seq_len(Iterations)) {
        Rarefaction[i]<-length(unique(sample(Data$genus,Limit,replace=FALSE)))
        }
    Rarefaction = mean(Rarefaction)
    return(c(Raw,Rarefaction))
    }

# Because I am not familiar with the theoretical justifications for different divvy parameteriziations, 
# I have hard-coded in the values (and in some cases direct copy/pasted code) used in the divvy vignette.
calcSpatial = function(Data) {
    rWorld <- terra::rast()
    prj <- 'EPSG:8857'
    rPrj <- terra::project(rWorld, prj, res = 200000) # 200,000m is approximately 2 degrees
    values(rPrj) <- 1:terra::ncell(rPrj)
    # For reasons that are absolutley insane and not clear to me, manually putting c('lng,"lat")
    # in the relevant divvy functions does NOT lead to a good outcome, and it is important
    # to create these intermediate objects. I can see NO logical reason why this would be the case,
    # but it absolutely matters and seems to be why I got so many wrong results before.
    xyCartes <- c('lng','lat')
    xyCell <- c('cellX','cellY')
    # taxon occurrences
    # retrieve coordinates of raster cell centroids
    llOccs <- terra::vect(Data, geom = xyCartes, crs = 'epsg:4326')
    prjOccs <- terra::project(llOccs, prj)
    Data$cell <- terra::cells(rPrj, prjOccs)[,'cell']
    Data[, xyCell] <- terra::xyFromCell(rPrj, Data$cell)
    Cookies = cookies(dat=Data,xy=xyCell,iter=500,nSite=15,r=1500,weight=TRUE,crs=prj,output='full')
    return(Cookies)
    }

# A wrapper for the final result of the first experiment
richnessMacro = function(Duration=550,Dataset="obis.shelf") {
    FinalMatrix = matrix(NA,nrow=Duration,ncol=4)
    colnames(FinalMatrix) = c("TRaw","TRare","SRaw","SRare")
    xyCell <- c('cellX','cellY')
    Progress = txtProgressBar(min=0,max=Duration,style=3,initial=0)
    for (i in seq_len(Duration)) {
        Record = createRecord(Target=Dataset)
        FinalMatrix[i,c("TRaw","TRare")] <- calcTraditional(Record)
        Subsample = calcSpatial(Record)
        Summary = sdSumry(Subsample,taxVar = 'genus',xy = xyCell,quotaN=100,crs = 'EPSG:8857')
        FinalMatrix[i,c("SRaw")]<-mean(Summary$nTax)
        FinalMatrix[i,c("SRare")]<-mean(Summary$CRdiv)
        setTxtProgressBar(Progress,i)
        }
    close(Progress)
    return(FinalMatrix)
    }

# branching evolutionary model
branchTaxa = function(Connection=Ecos,p=0.20) {
    # Note that loading into R will be slow given the size
    Before = sf::st_read(Connection,query=paste0("SELECT * FROM obis.shelf;"))
    BeforeGamma = length(unique(Before$genus))
    Delta = ceiling(BeforeGamma*p)
    Parents = sample(unique(Before$genus),Delta,replace=FALSE)
    for (parent in Parents) {
        Occurrences = which(Before$genus==parent)
        if (length(Occurrences) < 2) {next;} # impossible to branch a singleton
        Half = floor(length(Occurrences)*0.5)
        NewOccurrences = sample(Occurrences,Half,replace=FALSE)
        Before[NewOccurrences,"genus"]<-paste0(parent,"redux")
        }
    return(Before)
    }   

################################################### ANALYSIS ################################################
# Create a single test time-slice for sanity check and later plotting
# Notice that i have set different parameters for Loci, Base, and Factor than is default in the main macro
# In hindsight, I am not happy with these parameterization and I think it would need to be explore more
# systematically or possibly an entirely new method created
Single = createRecord(Connection=Ecos,Loci=5,Method="Fixed",Base=0.2,Factor=20,Target="obis.shelf")
Single = st_as_sf(Single,coords=c("lng","lat"),crs=4326)
sf::st_write(Single,GDAL,layer="results.single",layer_options=c("GEOMETRY_NAME=geom","LAUNDER=true","SPATIAL_INDEX=GIST"))

# First Analysis Output
FirstOutput = richnessMacro(1000,Dataset="obis.shelf")
COV = apply(FirstOutput,2,function(x) sd(x)/mean(x))

# Second Analysis Output
Radiation = branchTaxa(Ecos,0.20)
dbSendQuery(Ecos,"DROP TABLE IF EXISTS obis.radiation CASCADE;")
sf::st_write(Radiation,GDAL,layer="obis.radiation",layer_options=c("GEOMETRY_NAME=geom","LAUNDER=true","SPATIAL_INDEX=GIST"))
SecondOutput = richnessMacro(1000,Dataset="obis.radiation")

# Store results for future
dbSendQuery(Ecos,"CREATE SCHEMA IF NOT EXISTS results;")
dbWriteTable(Ecos,c("results","earth2"),value=as.data.frame(FirstOutput),row.names=FALSE)
dbWriteTable(Ecos,c("results","earth2gbe"),value=as.data.frame(SecondOutput),row.names=FALSE)