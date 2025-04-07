# Introduction
This is a new public-facing repository for the Earth-2 spatial subsampling null model. The Earth-2 spatial subsampling model is an attempt to test the effectiveness of different fossil biodiversity metrics at accounting for noise from spatial heterogeneity in sampling. A full description of the procedure can be found within this repository in the [Outline](/outline.md) markdown document.

## Relevant Files
1. [Outline](/outline.md) is the basic manuscript outline.
2. [downloadOBIS](/Data/downloadOBIS.r) is a script for downloading data from OBIS and storing it in the PostgreSQL database.
3. [spatialSubsampling](/Analyses/spatialSubsampling.r) is a script for generating the null model and outputs
4. [makeFigures](/Analyses/makeFigures.r) is a script for generating the final figures (incomplete)

## Important Notes About this Repository
1. Although the code in this repository is presented as [R Language](https://www.r-project.org/) scripts, thus giving the impression that this project uses an R-based workflow, the reality is that these R scripts make extensive use of (and therefore assumes the installation of) a PostgreSQL database. Instructions for installing and configuring PostgreSQL (and PostGIS) go beyond the remit of this README, but here is a key tip. Mac users are strongly encouraged to use [PostgresApp](https://postgresapp.com/). Compiling from source or using tools like homebrew will only lead to pain in the longrun as you will constantly run into verison conflicts among GDAL, postgis, PostgreSQL, AND R. Windows users are encouraged to switch to Mac.

2. The original code for this was split off from code held in a private repository in the [UW-Macrostrat](https://github.com/UW-Macrostrat) GitHub organization, which holds code relating to multiple projects - some of which are not ready for public dissemination. An unfortunate consequence of this move is that the commit history of the original coding efforts is broken, so access to earlier iterations of the code are not available to the public.

3. The code in this repository is meant to run as reproducibly as possible (barring the difficulties of point 1) and therefore makes almost all of its calls to dynamic web services rather than static data files. However, finding a stable REST service for the Marine Ecoregions of the World Dataset has been an absolute hell over the years. I ended up downloading it as a Shapefile from https://databasin.org/datasets/3b6b12e7bcca419990c9081c0af254a2/, resaving it as a geopackage, and then posting it in this repo. You can see my comments in the R scripts for a glimpse into the madness.

## Acknowledgements
This work was supported by (while serving at) the National Science Foundation and the Arizona Geological Survey at the University of Arizona.