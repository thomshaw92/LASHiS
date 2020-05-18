
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Nov 21 09:35:52 2019
@author: uqtshaw
"""

from os.path import join as opj
import os
from nipype.interfaces.base import (TraitedSpec,
                                    CommandLineInputSpec,
                                    CommandLine,
                                    File,
                                    traits)
from nipype.interfaces.c3 import C3d
from nipype.interfaces.utility import IdentityInterface#, Function
from nipype.interfaces.io import SelectFiles, DataSink
from nipype.pipeline.engine import Workflow, Node, MapNode
from nipype.interfaces.ants import Registration, RegistrationSynQuick
from nipype.interfaces.ants import ApplyTransforms, N4BiasFieldCorrection, DenoiseImage

os.environ["FSLOUTPUTTYPE"] = "NIFTI_GZ"

#setup for Workstations

data_dir = '/path/to/ADNI_BIDS/data/'
experiment_dir = '/path/to/ADNI_BIDS/'
#where the atlases live
atlas_dir = '/path/to/ashs_atlas_upennpmc_20170810/'
##############
#the outdir
output_dir = 'output_dir'
#working_dir name
working_dir = 'derivatives/nipype_working_dir_ADNI_pp'

#other things to be set up
ses_list = ['ses-01', 'ses-02', 'ses-03']
subject_list = sorted(os.listdir(experiment_dir+'data/'))

#####################

wf = Workflow(name='Workflow_preprocess_ADNI')
wf.base_dir = os.path.join(experiment_dir+working_dir)

# create infosource to iterate over iterables
infosource = Node(IdentityInterface(fields=['subject',
                                            'ses']),
                  name="infosource")
infosource.iterables = [('subject', subject_list),
                        ('ses', ses_list)]


templates = {#tse
             'tse' : '{subject}/{ses}/anat/{subject}_{ses}*run-1_T2w.nii.gz',
             #mprage
             'mprage' : '{subject}/{ses}/anat/{subject}_{ses}*run-1_T1w.nii.gz',
             }
# change and add more strings to include all necessary templates for histmatch
histmatch_files = {'ashs_t1_template' : 'template/template.nii.gz',
                 'ashs_t2_template' : 'train/train000/tse.nii.gz',
                 }

selectfiles = Node(SelectFiles(templates, base_directory=data_dir), name='selectfiles')

selecttemplates = Node(SelectFiles(histmatch_files, base_directory=atlas_dir), name='selecttemplates')

wf.connect([(infosource, selectfiles, [('subject', 'subject'),
                                       ('ses', 'ses')])])

#wf.connect([(infosource, selecttemplates, [('ses','ses')])])


############
## Step 1 ##
############
# Bias correct the T1 and TSE
#input_image not input
T1_N4_n = MapNode(N4BiasFieldCorrection(dimension = 3,
                                        bspline_fitting_distance = 300,
                                        shrink_factor = 2,
                                        n_iterations = [50,50,40,30],
                                        rescale_intensities = True,
                                        num_threads = 20),
name = 'T1_N4_n', iterfield=['input_image'])

wf.connect([(selectfiles, T1_N4_n, [('mprage','input_image')])])

T2_N4_n = MapNode(N4BiasFieldCorrection(dimension = 3,
                                        bspline_fitting_distance = 300,
                                        shrink_factor = 2,
                                        n_iterations = [50,50,40,30],
                                        rescale_intensities = True,
                                        num_threads = 20),
name = 'T2_N4_n', iterfield=['input_image'])
wf.connect([(selectfiles, T2_N4_n, [('tse','input_image')])])

############
## Step 2 ##
############
#Denoise all
T1_den_n = MapNode(DenoiseImage(dimension = 3,
                                noise_model = 'Rician',
                                num_threads = 20),
name = 'T1_den_n', iterfield=['input_image'])
wf.connect([(T1_N4_n, T1_den_n, [('output_image','input_image')])])

T2_den_n = MapNode(DenoiseImage(dimension = 3,
                                noise_model = 'Rician',
                                num_threads = 20),
name = 'T2_den_n', iterfield=['input_image'])

wf.connect([(T2_N4_n, T2_den_n, [('output_image','input_image')])])
'''''
############
## Step 3 ##
############
#Histmatch all
T1_histmatch_n = MapNode(C3d(interp="Sinc", pix_type='float', args='-histmatch 5' , out_files = 'normalised_MPRAGE_n.nii.gz'),
                             name='T1_histmatch_n', iterfield=['in_file', 'opt_in_file']),
wf.connect([(T1_den_n, T1_histmatch_n, [('output_image', 'opt_in_file')])])
wf.connect([(selecttemplates, T1_histmatch_n, [('ashs_t1_template', 'in_file')])])
T2_histmatch_n = MapNode(C3d(interp="Sinc", pix_type='float', args='-histmatch 5' , out_files = 'normalised_TSE_n.nii.gz'),
                             name='T2_histmatch_n', iterfield=['in_file', 'opt_in_file']),
wf.connect([(T1_den_n, T1_histmatch_n, [('output_image', 'opt_in_file')])])
wf.connect([(selecttemplates, T1_histmatch_n, [('ashs_t1_template', 'in_file')])])
MAG_register_TSE_whole_to_UMC_TSE_whole_n = MapNode(RegistrationSynQuick(transform_type = 'r', use_histogram_matching=True),
                         name='MAG_register_TSE_whole_to_UMC_TSE_whole_n', iterfield=['moving_image'])
wf.connect([(selecttemplates, MAG_register_TSE_whole_to_UMC_TSE_whole_n, [('umc_tse_whole_template', 'fixed_image')])])
wf.connect([(selectfiles, MAG_register_TSE_whole_to_UMC_TSE_whole_n, [('mag_tse_whole', 'moving_image')])])
'''''

################
## DATA SINK  ##
################
datasink = Node(DataSink(base_directory=experiment_dir+working_dir,
                         container=output_dir),
                name="datasink")

wf.connect([(T1_den_n, datasink, [('output_image','mp2rage_n4_denoised')])]) #Step 2
wf.connect([(T2_den_n, datasink, [('output_image','tse_n4_denoised')])]) #Step 2



###################
## Run the thing ##
###################

wf.write_graph(graph2use='flat', format='png', simple_form=False)

wf.run(plugin='SLURMGraph', plugin_args = {'dont_resubmit_completed_jobs': True} )
#wf.run()
#wf.run(plugin='MultiProc', plugin_args = {'n_procs' : 30})
'''
# # run as MultiProc
wf.write_graph(graph2use='flat', format='png', simple_form=False)
#wf.run(plugin='SLURMGraph', plugin_args = {'dont_resubmit_completed_jobs': True} )
'''
