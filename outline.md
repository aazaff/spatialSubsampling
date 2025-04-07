# An investigation of spatial subsampling for global biodiversity timeseries with null modelling

## Introduction

Taxon occurrence data in the fossil record have patchy spatial distributions, which may stem from inconsistent sampling effort by paleontologists. Spatial subsampling has been proposed as a method to mitigate such spatial sampling inequities, but it is possible that such standardization removes as much, or more, “real” biological signal as the “fake” sampling-related signal it seeks to correct. The following are two null model procedures to test this possibility.

## Methods
Earth-2.This experiment hypothesizes a fictional Earth-2 with two key properties. First, Earth-2 has no extinction, origination, immigration, emmigration, or extirpation. Its biological and ecological state - including global richness, geography, and biogeography - has remained unchanged from 1,000 ma to 0 ma. Second, despite Earth-2’s apparent lack of dynamic evolutionary and geologic processes, it still, inexplicably, has a fossil record and this fossil record is just as spatiotemporally variable and incomplete as in the real world.

A perfect reconstruction of global, Earth-2 richness through time would be a smooth horizontal line. Therefore, any variations in richness observed by an Earth-2 paleobiologist are noise introduced from sampling. The greater the variance observed in an Earth-2 biodiversity reconstruction the more sensitive the richness calculation (standardization) is to noise. The following richness metrics are tested: 1) no standardization (TRaw); 2) traditional occurrence-based standardization (TRare); 3) spatially subsampled (SRaw); and 4) spatial and occurrence-based standardization (SRare). The coefficient of variation (COV) is used as a scale-invariant measure of the time-series error (Equation 1). 
	Eq. 1  $`\dfrac{\sigma}{\bar{x}}`$
The greater the COV the less effective a method of calculating richness is at removing noise from spatial sampling bias.

Earth-2 is populated using a spatial join of the Marine Ecoregions of the World (MEOW) and Ocean Biogeographic Information Systems (OBIS) datasets (Figure 1). This complete dataset represents the observed state of the world at 0 ma and also the true, yet incompletely observed, state of the world from 1,000 ma to 1 ma. 

A spatially heterogeneous random subsample of Earth-2 is taken 1,000 times to simulate an incompletely observed fossil record in terms of both sampling quantity and spatial coverage. Specifically, the geologic record of Earth-2 is broken into 1,000 distinct intervals, each with their own spatial pattern of sampling. First, a set of 6 marine ecoregions are randomly selected as sampling loci. A sampling locus is a region with unusually high concentrations of sampled fossil occurrences. This is meant to mimic the pattern observed in real-world data where the fossil record for a given geologic interval tends to be dominated by data collected from a few well-sampled, fossil-rich basins. For example, the Hirnantian fossil record consists of five sample-dense regions (Fig. 2) with geometrically decreasing sample coverage away from these clusters. Ten percent of occurrences within the selected ecoregions are randomly selected. Another one percent of occurrences from other ecoregions within the same province(s) as the loci ecoregions are randomly sampled. Last 0.001 percent of occurrences from all other ecoregions are sampled (Fig. 3).


Figure 1. Map of Earth-2. Each point represents a taxon occurrence record in OBIS, with the color reflecting its ecoregion. 


Figure 2. Map of Hirnantian occurrences in the Paleobiology Database. 

Figure 3. Map of 

Earth-2 Biodiversification Event.—Our second test is of how effective different methods of standardizing richness are at detecting “real” evolutionary turnover in the global biota when overprinted with a spatially irregular sampling regime. In this next experiment, a great biodiversity event (GBE), specifically defined as a ~20% increase in global generic richness, is simulated. A test is then performed to see which methods of standardizing richness most reliably detect this increase.

First, Earth-2 is divided into two time intervals, one representing “before” and the other “after” the GBE. The “before” snapshot is identical to the Earth-2 dataset used in the original experiment. The “after” snapshot, however, is a one-time variant of Earth-2 that retains the same number of occurrences and spatial distribution as before, but total global generic richness has been increased by 20%. 

This simulated increase is achieved by simulating a branching model of origination. Fifteen percent of genera are randomly selected and half of the occurrences for these genera are reclassified as a new genus. This method of simulating a GBE is especially chosen because it preserves all other characteristics of the dataset (Fig. 2).

Both the “before” and “after” snapshots are then randomly spatially subsampled 1,000 times each, using the same 4-loci procedure as in the previous experiment. Different versions of standardized richness, and their associated confidence intervals, are then calculated for each iteration and the number of times that a statistically significant increase in richness is detected is tabulated.

## Results