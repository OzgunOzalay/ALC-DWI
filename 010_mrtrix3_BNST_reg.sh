#! /bin/bash
# mrtrix 3 connectome 

# shellcheck disable=SC2154
cd "$analysis_dir" || exit

echo -e "\n"
echo -e "${BWhite}Step 010:${Color_Off} Registering ROIs and creating combined parcellation mrtrix3:"
echo -e "\n"

export SUBJECTS_DIR="$result_dir"/FS/subjects

while IFS= read -r subject
do

  MRI_DIR="$result_dir"/FS/subjects/"$subject"/mri
  mrtrix_dir="$analysis_dir"/"$subject"/dwi/mrtrix3

  # Create folder for the ROIs
  if [ ! -d "$mrtrix_dir"/ROIs ]; then
      mkdir -p "$mrtrix_dir"/ROIs
  fi

  # Go to the folder
  cd "$mrtrix_dir"/ROIs || exit

  # Copy aseg.mgz and aparc+aseg.mgz from FreeSurfer results
  cp "$MRI_DIR"/aseg.mgz .
  cp "$MRI_DIR"/aparc+aseg.mgz .

  # Convert aseg.mgz and aparc+aseg.mgz to nii.gz
  mri_convert aseg.mgz aseg.nii.gz
  mri_convert aparc+aseg.mgz aparc+aseg.nii.gz

    # Subcortical structures from aseg
  declare -A aseg_ids=(
  [L_hippocampus]=17 [R_hippocampus]=53
  [L_amygdala]=18 [R_amygdala]=54
  [L_hypothalamus]=26 [R_hypothalamus]=58
  )

  for roi in "${!aseg_ids[@]}"; do
      mri_binarize --i aseg.nii.gz --match "${aseg_ids[$roi]}" --o "${roi}".nii.gz
      mrtransform "${roi}".nii.gz --template "$mrtrix_dir"/mean_b0_brain.mif \
          -linear "$mrtrix_dir"/fs2diff_mrtrix.txt \
          -interp nearest \
          "${roi}".mif \
          -force
  done

  # Cortical structures from aparc+aseg
  declare -A aparc_ids=(
  [L_insula]=1035 [R_insula]=2035
  [L_vmPFC]="1012 1014"  # medial orbitofrontal + frontal pole
  [R_vmPFC]="2012 2014"
  )

  for roi in "${!aparc_ids[@]}"; do
      mri_binarize --i aparc+aseg.nii.gz --match "${aparc_ids[$roi]}" --o "${roi}".nii.gz
      mrtransform "${roi}".nii.gz --template "$mrtrix_dir"/mean_b0_brain.mif \
          -linear "$mrtrix_dir"/fs2diff_mrtrix.txt \
          -interp nearest \
          "${roi}".mif \
          -force
  done

  BNST_L="$analysis_dir"/"$subject"/dwi/Reg/ROIs/BNST_L_DWI.mif
  BNST_R="$analysis_dir"/"$subject"/dwi/Reg/ROIs/BNST_R_DWI.mif

  cp "$BNST_L" "$mrtrix_dir"/ROIs/L_bnst.mif
  cp "$BNST_R" "$mrtrix_dir"/ROIs/R_bnst.mif

  # Combine Left and Right ROIs into a single mif parcellation file
  for hemi in L R; do
    # Set output file name
    OUTFILE="$hemi"_combined_parc.mif

    # Initialize
    FIRST=1
    
    # Create array of ROI files to process in order
    ROI_FILES=(
      "${hemi}_bnst.mif"
      "${hemi}_amygdala.mif" 
      "${hemi}_hippocampus.mif"
      "${hemi}_hypothalamus.mif"
      "${hemi}_insula.mif"
      "${hemi}_vmPFC.mif"
    )

    # Process ROIs in order with sequential labels
    for ((i=0; i<${#ROI_FILES[@]}; i++)); do
      LABEL=$((i + 1))
      ROI="${ROI_FILES[$i]}"
      
      echo "Processing $ROI as label $LABEL"

      # Multiply binary mask by label ID
      mrcalc "$ROI" $LABEL -mult temp_${LABEL}.mif

      if [ $FIRST -eq 1 ]; then
        cp temp_${LABEL}.mif $OUTFILE
        FIRST=0
      else
        mrcalc $OUTFILE temp_${LABEL}.mif -add $OUTFILE -force
      fi
    done

    # Clean up
    rm temp_*.mif


  done



# Combine all ROIs into a single mif parcellation file

# Initialize
FIRST=1

# Set output file name
OUTFILE="combined_parc.mif"

# Create an array of all ROI files
ROI_FILES=(
  L_bnst.mif
  R_bnst.mif
  L_amygdala.mif
  R_amygdala.mif
  L_hippocampus.mif
  R_hippocampus.mif
  L_insula.mif
  R_insula.mif
  L_vmPFC.mif
  R_vmPFC.mif
)

# Process ROIs in order with sequential labels
for ((i=0; i<${#ROI_FILES[@]}; i++)); do
  LABEL=$((i + 1))

  ROI="${ROI_FILES[$i]}"

  echo "Processing $ROI as label $LABEL"

  # Multiply binary mask by label ID
  mrcalc "$ROI" $LABEL -mult temp_${LABEL}.mif

  if [ $FIRST -eq 1 ]; then
    cp temp_${LABEL}.mif $OUTFILE
    FIRST=0
  else
    mrcalc $OUTFILE temp_${LABEL}.mif -add $OUTFILE -force
  fi

  # Clean up
  rm temp_*.mif

  # Increment label
  LABEL=$((LABEL + 1))

done
  

    # Clean up
    rm temp_*.mif



done < <(grep -v '^ *#' subj_list.txt)


echo -e "\n"
echo -e "${Green}Step 010 completed!"
echo -e "${Color_Off}###################\n"