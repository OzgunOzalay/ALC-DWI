#!/bin/bash

# This is the main script for DWI analysis of Alcohol-Sex study
# oozalay@unmc.edu

# shellcheck disable=SC1090


# Declare folders here
export base_path="$(dirname "$(dirname "$(readlink -fm "$0")")")"
export data_dir=$base_path/Data
export script_dir=$base_path/Scripts
export analysis_dir=$base_path/Analysis
export result_dir=$base_path/Results
export stat_dir=$base_path/Stats


# Source helper functions and variables 
source "$script_dir"/999_Helpers.sh


# 1-Copy Data to Analysis folders
# source $script_dir/001_Copy_Data.sh

# 2-Denoise data
# source $script_dir/002_Denoise.sh


# 3-TopUp - Correct distortions caused by magnetic field inhomogeneities
# source $script_dir/003_Topup.sh


# 4-Eddy current correction
# source $script_dir/004_Eddy_Corr.sh


# 5-Template <--> DTI registration
# source $script_dir/005_Reg_MNI2DWI.sh


# 6-Microstructure Diffusion Toolbox (MDT) Processing
# source $script_dir/006_mdt.sh

# 7-mrtrix3 pre-processing
# source $script_dir/007_mrtrix3_prep.sh


# 8-mrtrix3 probabilistic tracking
# source $script_dir/008_mrtrix3_tckgen.sh

# 9-mrtrix3 tcksift2
# source $script_dir/009_mrtrix3_tcksift2.sh

# 10-mrtrix3 Register BNST parcellation to DTI
# source $script_dir/010_mrtrix3_BNST_reg_v2.sh


# 11-mrtrix3 connectome
source $script_dir/011_mrtrix3_conn.sh


# 15-Normalize mrtrix3 Connectivity Matrices
# source $script_dir/015_Normalize_mrtrix3_Mats.sh


# 16 !!! Run GRETNA Manually !!!


# 17-Prepare GRETNA results for R
# source $script_dir/017_Prepare_Graph_Metrics_FSL.sh
# source $script_dir/017_Prepare_Graph_Metrics_mrtrix3.sh


# 18-Statistics for Graph metrics
# R CMD BATCH $script_dir/018_Calc_Graph_Metrics_FSL.R
# R CMD BATCH $script_dir/018_Calc_Graph_Metrics_mrtrix3.R



