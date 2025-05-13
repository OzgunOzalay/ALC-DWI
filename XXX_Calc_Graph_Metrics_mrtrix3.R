#!/usr/bin/env Rscript

library(tibble) # add_column
library(car) # Anova

resdir <- "/media/ozgun/Ozzy_AnV/Alcohol/Stats/Graph/mrtrix3/"
setwd(resdir)

# Get extra covars and add them to data.frame after the first two cols
covars <- read.csv("/media/ozgun/Ozzy_AnV/Alcohol/Scripts/Data/Covars.csv")


################
# Global Stats #
################

# Read in Global metrics results file
global_metrics <- read.csv("Global_Metrics.csv")


# Make Group and Gender factors
global_metrics$Group <- as.factor(global_metrics$Group)
global_metrics$Gender <- as.factor(global_metrics$Gender)


# Extract Global metrics from column names. First two cols are Subject and Group
# Adjust according to your "Global_Metrics.csv" file.
globals <- colnames(global_metrics)[c(-1:-4)]

# Do the stats
for (metric in globals) {
  model <- aov(get(metric) ~ Group * Gender, data = global_metrics)
  model <- Anova(model, type = "III")

  # Save results
  write.csv(model, paste0("Stats_", metric, ".csv"))

}


###############
# Nodal Stats #
###############


nodals <- c("N_BC", "N_DC", "N_EL")
rois <- c("lAMY", "rAMY", "lINS", "rINS", "lBNS", "rBNS", "lHIP", "rHIP", "lHYP", "rHYP", "lPFC", "rPFC") # nolint: line_length_linter.

# Create an empty dataframe for Nodal stats results
nodal_stats <- data.frame(matrix(nrow = 3, ncol = length(rois)))
rownames(nodal_stats) <- c("Group", "Gender", "Group:Gender")
colnames(nodal_stats) <- rois


# Do the stats
for (metric in nodals) {
  nodal_data <- read.csv(paste0(metric, ".csv"))
  nodal_data$Group <- as.factor(nodal_data$Group)
  nodal_data$Gender <- as.factor(nodal_data$Gender)

  for (Region in rois) {
    model <- aov(get(Region) ~ Group * Gender, data = nodal_data)
    model <- Anova(model, type = "III")
    nodal_stats["Group", Region] <- model["Group", 4]
    nodal_stats["Gender", Region] <- model["Gender", 4]
    nodal_stats["Group:Gender", Region] <- model["Group:Gender", 4]
  }
  # Save results
  write.csv(nodal_stats, paste0("Stats_", metric, ".csv"))
}