Unreconciled data is the original data that was created by LASHiS, Freesurfer, etc.
This had been augmented in such a way that the data was concatenated by the common subfields as described in the LASHiS paper.
This also includes demographic details of the participants and both image and subject IDs.


FULLY reconciled data is augmented by the script in Scripts/Analysis/reconcileDataADNI.R
It is the data that will be read into the STAN model.
