#!/bin/bash
#
# script processResults.sh
# date:  Feb 18, 2021
# usage: ./processResults.sh authMlRunningJobId workingFolderName
# reference: https://cloud.google.com/vision/automl/docs/quickstart
#

clear

#************************************************************************************************************
#0. Prepare script parameters

#load run as service credentials
#https://cloud.google.com/docs/authentication/production
sakAuthFileName="~/yourServiceAccountKeyFile.json"
export GOOGLE_APPLICATION_CREDENTIALS="$sakAuthFileName"

#perform a cloud bucket ls operation so the authorize cloud operations window will come up first thing - enhancement: avoid automatically
gsutil ls

runningJobId="$1"
workingDir="$2"
projectId=$(gcloud config list --format 'value(core.project)' 2>/dev/null)

echo "projectId is $projectId"

cd ~/$workingDir

#read stored workingUrl (created by runlogic.sh script)
workingUrl=$(<workingUrl.txt)

echo "Script processResults.sh video from URL: $workingUrl and $workingDir for project: $projectId"
echo ""

#query the running job's completion status and store the results in environment variable
runningStatus=$(curl -s -X GET \
-H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
https://automl.googleapis.com/v1/projects/$projectId/locations/us-central1/operations/$runningJobId)

#save job completion status to file
echo "Job Completion status:"
echo "$runningStatus" | jq . > jobStatus.json
echo ""

#add local job create and job update time values, could probably determine time zone dynamically but hard code for now from
#https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
#America/New_York, America/Chicago, America/Denver, America/Los_Angeles
jobCreateTime=$(jq -n -r --argjson data "$runningStatus" '$data.metadata.createTime')
localJobCreateTime=$(TZ=America/New_York date -d "$jobCreateTime")
jq --arg localJobCreateTime "$localJobCreateTime" '.metadata.createTimeLocal = $localJobCreateTime' jobStatus.json > jobStatusCreate.json

jobUpdateTime=$(jq -n -r --argjson data "$runningStatus" '$data.metadata.updateTime')
localJobUpdateTime=$(TZ=America/New_York date -d "$jobUpdateTime")
jq --arg localJobUpdateTime "$localJobUpdateTime" '.metadata.updateTimeLocal = $localJobUpdateTime' jobStatusCreate.json > jobStatusUpdate.json

rm jobStatusCreate.json
mv jobStatusUpdate.json jobStatus.json

#display current job completion status to screen
cat jobStatus.json

#stored true/false for if job is completed or not
isDone=$(jq -n -r --argjson data "$runningStatus" '$data.done')

echo ""
if [[ $isDone == 'true' ]]; then

   echo "*** The job has completed! ***"
   echo ""

   #get the name of the output directory in the bucket that was used to store the files containing the prediction results
   gcsOutputDirectory=$(jq -n -r --argjson data "$runningStatus" '$data.metadata.batchPredictDetails.outputInfo.gcsOutputDirectory')

   #copy the results locally, combine into one file, only take images with a prediction, sort that list and store in an output file
   cd ~/$workingDir
   gsutil -q cp $gcsOutputDirectory/* .
   cat *.jsonl > results.jsonx
   grep annotation_spec_id results.jsonx > results.jsony
   rm -f -- results.jsonl
   sort results.jsony > results.jsonl
   rm results.jsonx
   rm results.jsony

   #make a script to copy the jpg's that model marked as found to a new directory
   #get lines with result (should be all) | remove first page to where filename starts | remove after first quote " | append foundDir to end of each line

   #create a new Windows script that will create a folder with the images with predictions, alternatively method would be to download these images from the bucket
   #and tar/zip them up and then download that
   fileNameStart=`expr length "{\"ID\":\"gs://$workingDir//"`

   echo "echo $workingUrl" > copyFound1.cmd
   echo "mkdir $workingDir" >> copyFound1.cmd
   echo "mkdir $workingDir\foundDir" >> copyFound1.cmd
   echo "cd $workingDir" >> copyFound1.cmd
   echo "youtube-dl -o 'media.mp4' -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 $workingUrl" >> copyFound1.cmd
   echo "ffmpeg -i media.mp4 -vf \"fps=fps=5,drawtext=text='%%{pts\:hms}': fontsize=60: x=(w-tw)/2: y=h-(2*lh): fontcolor=white: box=1: boxcolor=0x00000000@1\" -qscale:v 3 %%03d.jpg" >> copyFound1.cmd
   grep jpg results.jsonl | cut -c$fileNameStart-99999 |  cut -d\" -f1 | awk '{print $0, "foundDir"}' | awk '{print "copy " $0}' >> copyFound1.cmd
   
   echo "cd foundDir" >> copyFound1.cmd

   echo "Windows script to display predicted frames: /home/$USER/$workingDir/copyFound1.cmd"
   echo ""
   echo "cd ~/$workingDir"
   echo "ls -ltr"
   echo ""

   #remove the cloud bucket to clean up
   #gsutil -m rm -r gs://$workingDir/

else
  echo "Job has not completed yet..."
fi

echo ""
