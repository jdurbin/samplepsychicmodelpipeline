

# Path where all other files should be found.   
OUTPUT_ROOT=/Users/james/ucsc/exp/singlecellpipeline/BRAIN2/

EXPRESSION=$(OUTPUT_ROOT)/data/exprMatrix.tsv  		# Expression data in genes (rows) x samples (cols) tab file

# Dichotomized metadata in target class (rows) x samples (cols) tab file
# First column is the name of the clusters.  This name will be used in many 
# subsequent file creation steps.  
METADATA=$(OUTPUT_ROOT)/data/meta_dichotomized.tsv	



# Make all will perform all the steps needed to subsample, select a models, train models. 
all: clean subsamplejobs modelselectionjobs bestmodels modeltrainjobs
	
# Remove files created by this makefile...
clean: 
	rm -rf $(OUTPUT_ROOT)/data_subsample
	rm -rf raw
	rm -rf results
	rm -rf models

# This data is highly imbalanced.  Classifiers can handle some 
# imbalance in the training classes, but when it gets too large
# the imbalance causes problems.   Subsample the data so that
# each training file contains all of the positive examples and 
# at most 2X as many *randomly sampled* negative examples.
# Note: running this serially took 25 minutes on BRAIN2 dataset. 
# export JAVA_OPTS="-Djava.util.Arrays.useLegacyMergeSort=true -Xmx10000m -server -Xss40m"  
subsamplejobs:
	mkdir -p $(OUTPUT_ROOT)/data_subsample	
	./scripts/makeSubsampleJobs.gv $(EXPRESSION) $(METADATA) $(OUTPUT_ROOT) > subsample.jobs
	./scripts/runserially.gv subsample.jobs	
	
#  Each model selection job will output several files into the raw/ subdirecotry. 
#  These files summarize the results of the model selection search.  *summary* is most used. 
#  14 minutes
modelselectionjobs:
	mkdir -p raw
	mkdir -p results
	./scripts/makeModelSelectionJobs.gv $(EXPRESSION) $(METADATA) $(OUTPUT_ROOT) > modelselection.jobs
	./scripts/runserially.gv modelselection.jobs

# Figure out which of the algorithms/hyperparameters is best for each class attribute. 
# In the do_one.cfg we only consider one, so this step doesn't do much. 
bestmodels:
	wmBestModels raw/*summary* > results/best.tab

# Took about 7 minutes. 
modeltrainjobs:
	mkdir -p models
	./scripts/makeModelTrainJobs.gv $(EXPRESSION) $(METADATA) $(OUTPUT_ROOT) results/best.tab > modeltrain.jobs
	./scripts/runserially.gv modeltrain.jobs


# Here is a super trivial script to run all the commands in a jobs file one at a time:
# ./scripts/runserially.gv subsample.jobs



#  If Java runs out of space, can increase it with -Xmx option like this: 
#
# export JAVA_OPTS="-Djava.util.Arrays.useLegacyMergeSort=true -Xmx10000m -server -Xss40m"
#
#