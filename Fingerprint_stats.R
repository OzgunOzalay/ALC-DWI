#!/usr/bin/env Rscript

# This script performs ANOVA and LME analyses on the BNST connectivity data.
# Input files are the outputs of Mrtrix3-tck2connectome command with -vector
# Files should have normalized connectivity values from BNST to all other regions
# Script assumes the following covariates:
# 1. Subject ID
# 2. Group (Control, Alcohol)
# 3. Gender (Male, Female)
# 4. Age

# oozalay@unmc.edu 


# =========================
#   Load Required Libraries
# =========================
library(tibble)
library(car)
library(ggplot2)
library(tidyr)
library(dplyr)
library(grid)
library(gridExtra)
library(lme4)

# =========================
#   Set Directories
# =========================
data_dir <- "/home/ozgun/Projects/Alcohol/Results/Network/Fingerprints"
resdir   <- "/home/ozgun/Projects/Alcohol/Stats/Network/Fingerprint"
setwd(data_dir)

# =========================
#   Load Covariates
# =========================
covars <- read.csv("/home/ozgun/Projects/Alcohol/Scripts/Data/Covars.csv")

# =========================
#   Read and Prepare Fingerprint Data
# =========================
csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)

# =========================
#   Output File Names
# =========================
MODEL_PDF_FILE_1      <- "ANOVA_Summary_Report.pdf"
MODEL_PDF_FILE_2      <- "LME_fixedHemisphere_Summary_Report.pdf"
MODEL_PDF_FILE_3      <- "LME_randomHemisphere_Summary_Report.pdf"
PLOT_PDF_FILE       <- "BNST_Connectivity_Plot.pdf"
PLOT_PNG_FILE       <- "BNST_Connectivity_Plot.png"
ANOVA_SUMMARY_CSV   <- "ANOVA_Summary_Report.csv"
ANOVA_STATS_CSV_PATTERN   <- "Stats_%s_%s.csv"  # Use sprintf(STATS_CSV_PATTERN, side, region)

# =========================
#   Model Formulas
# =========================
ANOVA_FORMULA <- Group * Gender
LME_FORMULA_1 <- value ~ group * gender + hemisphere + (1 | subject_id)
LME_FORMULA_2 <- value ~ group * gender * hemisphere + (1 + hemisphere | subject_id)

# Initialize results
result_list <- list()
column_names <- NULL

for (file in csv_files) {
  # Read first 2 rows with no header
  df <- tryCatch({
    read.csv(file, header = FALSE, nrows = 2, fill = TRUE, stringsAsFactors = FALSE)
  }, error = function(e) {
    message(sprintf("Skipping file due to read error: %s\n%s", file, e$message))
    return(NULL)
  })
  if (is.null(df) || nrow(df) < 2) next
  # Extract second row
  second_row <- df[2, ]
  # Use filename as Subject_ID
  subject_id <- tools::file_path_sans_ext(basename(file))
  # Store the row with ID
  result_list[[subject_id]] <- c(Subject_ID = subject_id, as.character(second_row))
}

# Pad rows to same length
max_cols <- max(sapply(result_list, length))
result_list <- lapply(result_list, function(row) {
  length(row) <- max_cols
  return(row)
})

# Combine into data frame
result_df <- as.data.frame(do.call(rbind, result_list), stringsAsFactors = FALSE)
colnames(result_df) <- c("Subject_ID", paste0("V", 1:(ncol(result_df) - 1)))
result_df <- result_df[, -1]
result_df$Subject_ID <- gsub("_fingerprint$", "", rownames(result_df))
rownames(result_df) <- NULL
result_df <- result_df[, c(6, 1:5)]

# =========================
#   Split by Hemisphere
# =========================
Left_BNST  <- subset(result_df, grepl("_L_", Subject_ID))
Right_BNST <- subset(result_df, grepl("_R_", Subject_ID))

# Prepare Left and Right BNST dataframes
cols_to_add_left  <- Left_BNST[, 2:6]
cols_to_add_right <- Right_BNST[, 2:6]

covars[, 5:(5 + ncol(cols_to_add_left) - 1)]  <- cols_to_add_left
Left_BNST  <- covars
covars[, 5:(5 + ncol(cols_to_add_right) - 1)] <- cols_to_add_right
Right_BNST <- covars

# Fix colnames
cols <- c("Subject", "Group", "Gender", "Age", "Amygdala", "Hippocampus", "vmPFC", "Insula", "Hypothalamus")
colnames(Left_BNST)  <- cols
colnames(Right_BNST) <- cols

# Convert region columns to numeric
Left_BNST[, 5:9]  <- lapply(Left_BNST[, 5:9], as.numeric)
Right_BNST[, 5:9] <- lapply(Right_BNST[, 5:9], as.numeric)

# =========================
#   ANOVA Statistics
# =========================
setwd(resdir)
Target_regions <- c("Amygdala", "Hippocampus", "Hypothalamus", "Insula", "vmPFC")

all_results <- list()

for (side in c("Left", "Right")) {
  data <- if (side == "Left") Left_BNST else Right_BNST
  for (region in Target_regions) {
    model <- aov(as.formula(paste(region, '~', ANOVA_FORMULA)), data = data)
    model <- Anova(model, type = "III")
    all_results[[paste(side, region)]] <- model
    write.csv(model, sprintf(ANOVA_STATS_CSV_PATTERN, side, region))
  }
}

# Create summary dataframe
summary_df <- data.frame(
  Side = character(),
  Region = character(), 
  Group_pval = numeric(),
  Gender_pval = numeric(),
  Interaction_pval = numeric(),
  stringsAsFactors = FALSE
)

for (name in names(all_results)) {
  side   <- strsplit(name, " ")[[1]][1]
  region <- strsplit(name, " ")[[1]][2]
  result <- all_results[[name]]
  p_values <- result[["Pr(>F)"]]
  summary_df <- rbind(summary_df, data.frame(
    Side = side,
    Region = region,
    Group_pval = p_values[1],
    Gender_pval = p_values[2], 
    Interaction_pval = p_values[3]
  ))
}

# Add significance indicators
summary_df <- summary_df %>%
  mutate(across(ends_with("_pval"), 
                list(sig = ~case_when(
                  . < 0.001 ~ "***",
                  . < 0.01  ~ "**", 
                  . < 0.05  ~ "*",
                  TRUE      ~ "ns"
                ))))

# Save summary as CSV
write.csv(summary_df, ANOVA_SUMMARY_CSV, row.names = FALSE)

# Create a formatted table for PDF
formatted_table <- summary_df %>%
  mutate(
    Group = paste(sprintf("%.3f", Group_pval), Group_pval_sig),
    Gender = paste(sprintf("%.3f", Gender_pval), Gender_pval_sig),
    Interaction = paste(sprintf("%.3f", Interaction_pval), Interaction_pval_sig)
  ) %>%
  select(Side, Region, Group, Gender, Interaction)

# =========================
#   Save ANOVA Summary as PDF
# =========================
pdf(MODEL_PDF_FILE_1, width = 11, height = 8)
grid.newpage()
pushViewport(viewport(layout = grid.layout(3, 1, heights = unit(c(1, 0.5, 4), "null"))))
grid.text("ANOVA Results Summary", vp = viewport(layout.pos.row = 1), gp = gpar(fontsize = 16))
grid.text(paste("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), 
          vp = viewport(layout.pos.row = 2), 
          gp = gpar(fontsize = 10))
grid.table(formatted_table, 
           vp = viewport(layout.pos.row = 3),
           theme = ttheme_minimal(
             core = list(fg_params=list(fontsize=9)),
             colhead = list(fg_params=list(fontsize=10, fontface="bold"))
           ))
dev.off()

cat("\nANOVA Results Summary:\n")
print(summary_df)

# =========================
#   Prepare Data for Plotting and Mixed Models
# =========================
left_long <- Left_BNST %>%
  pivot_longer(cols = Target_regions,
               names_to = "Region",
               values_to = "Value") %>%
  mutate(Side = "Left")

right_long <- Right_BNST %>%
  pivot_longer(cols = Target_regions,
               names_to = "Region",
               values_to = "Value") %>%
  mutate(Side = "Right")

combined_long <- rbind(left_long, right_long)

# =========================
#   Mixed-Effects Models (lme4)
# =========================

# Rename columns for modeling
combined_long <- combined_long %>%
  rename(subject_id = Subject, group = Group, gender = Gender, hemisphere = Side, value = Value)

combined_long$subject_id <- as.factor(combined_long$subject_id)
combined_long$group      <- as.factor(combined_long$group)
combined_long$gender     <- as.factor(combined_long$gender)
combined_long$hemisphere <- as.factor(combined_long$hemisphere)

# --- Model 1: Random Intercept ---
lmer_model <- lmer(LME_FORMULA_1, data = combined_long)
cat("\nLME Model Summary (value ~ group * gender + hemisphere + (1 | subject_id)):\n")
print(summary(lmer_model))

# Save lmer summary as PDF
lmer_summary_text <- capture.output(summary(lmer_model))
pdf(MODEL_PDF_FILE_2, width = 11, height = 8)
grid.newpage()
pushViewport(viewport(layout = grid.layout(3, 1, heights = unit(c(1, 0.5, 4), "null"))))
grid.text("LME Model Results Summary", vp = viewport(layout.pos.row = 1), gp = gpar(fontsize = 16))
grid.text(paste("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), 
          vp = viewport(layout.pos.row = 2), 
          gp = gpar(fontsize = 10))
grid.text(paste(lmer_summary_text, collapse = "\n"),
          vp = viewport(layout.pos.row = 3, x = 0, just = "left"),
          gp = gpar(fontsize = 8, fontfamily = "mono"))
dev.off()

# --- Model 2: Random Slope for Hemisphere ---
lmer_model2 <- lmer(LME_FORMULA_2, data = combined_long)
cat("\nLME Model 2 Summary (value ~ group * gender * hemisphere + (1 + hemisphere | subject_id)):\n")
print(summary(lmer_model2))

# Save lmer_model2 summary as PDF
lmer2_summary_text <- capture.output(summary(lmer_model2))
pdf(MODEL_PDF_FILE_3, width = 11, height = 8)
grid.newpage()
pushViewport(viewport(layout = grid.layout(3, 1, heights = unit(c(1, 0.5, 4), "null"))))
grid.text("LME Model 2 Results Summary", vp = viewport(layout.pos.row = 1), gp = gpar(fontsize = 16))
grid.text(paste("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), 
          vp = viewport(layout.pos.row = 2), 
          gp = gpar(fontsize = 10))
grid.text(paste(lmer2_summary_text, collapse = "\n"),
          vp = viewport(layout.pos.row = 3, x = 0, just = "left"),
          gp = gpar(fontsize = 8, fontfamily = "mono"))
dev.off()

# =========================
#   Plotting
# =========================
p_combined <- ggplot(combined_long, aes(x = group, y = value, fill = gender)) +
  geom_boxplot(outlier.size = 0.5) +
  facet_wrap(hemisphere ~ Region, scales = "fixed", ncol = 5, 
             labeller = labeller(hemisphere = c("Left" = "", "Right" = ""))) +
  labs(title = "BNST Connectivity by Region",
       y = "Value", 
       x = "Group") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, size = 14),
        strip.text = element_text(size = 12, face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        axis.text.y = element_text(size = 10),
        axis.title = element_text(size = 12),
        legend.title = element_text(size = 12),
        legend.text = element_text(size = 10),
        panel.spacing = unit(1, "lines")) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = 5))

print(p_combined)

ggsave(PLOT_PNG_FILE, 
       p_combined,
       width = 20,
       height = 10,
       dpi = 300,
       units = "in")

ggsave(PLOT_PDF_FILE, 
       p_combined,
       width = 20,
       height = 10,
       units = "in")

# =========================
#   Print Range of Values
# =========================
print("\nRange of values for each region:")
print(aggregate(value ~ Region + hemisphere, data = combined_long, FUN = function(x) c(min = min(x), max = max(x))))
