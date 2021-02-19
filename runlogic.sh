#!/bin/bash
#
# script runlogic.sh
# date:  Feb 18, 2021
# usage: ./runlogic.sh YouTubeVideoUrl GCPVisionModelId
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

workingUrl="$1"
modelId="$2"
projectId=$(gcloud config list --format 'value(core.project)' 2>/dev/null)

echo "projectId is $projectId"

IODLabel="IOD"

#use the current date plus HHMMSS as folder name to hold generated data files
workingDir=$(date +"%Y%m%d%H%M%S")

#************************************************************************************************************
#1. Prepare data for the prediction job

#set input parameters to a fixed value here for devevelopment and testing
#eg this Where's Waldo video with a number of live action scenes with a person wearing a red and white sweater and toque
#workingUrl="https://youtu.be/1RG6ThD6Ynw?t=45"
#modelId="IOD123456789"

#make a directory to store outputted data files
mkdir $workingDir
cd $workingDir

#save YouTube url and model ID in working folder for easy reference later
echo "$workingUrl" > workingUrl.txt
echo "$modelId" > modelId.txt

#use installed youtube-dl to process the supplied video
youtube-dl -o 'media.mp4' -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 $workingUrl

#use installed ffmpeg to generate jpg images at a rate of 5 images per second of video to quality #3 jpgs. #1 is best quality but they take up more disk space
ffmpeg -i media.mp4 -vf "fps=fps=5,drawtext=text='%{pts\:hms}': fontsize=60: x=(w-tw)/2: y=h-(2*lh): fontcolor=white: box=1: boxcolor=0x00000000@1" -qscale:v 3 %03d.jpg

#make a GCP Cloud Storage bucket in the US-CENTRAL1 region. This region is currently required for Google Vision work.
gsutil mb -b on -l US-CENTRAL1 gs://$workingDir

#make subfolder in this bucket - probably a better way but this works for now
touch file2.txt
gsutil cp file2.txt gs://$workingDir/output-dir/
rm file2.txt
gsutil rm gs://$workingDir/output-dir/file2.txt

#copy the generates frame jpg images to the bucket
gsutil -m cp *jpg gs://$workingDir

#remove the local Cloud shell jpgs files and mp4 file
rm *jpg
rm media.mp4

#Create the CSV file containg all of the image locations
#https://cloud.google.com/vision/automl/docs/quickstart#create_the_csv_file
gsutil ls gs://$workingDir/*jpg >batch_prediction.csv
gsutil cp batch_prediction.csv gs://$workingDir
rm batch_prediction.csv

#Prepare batch prediction as per
#https://cloud.google.com/vision/automl/docs/predict-batch
cp ~/request.json .

#replace the default bucket name which is the string "defaultBucketName" in file request.json with the in-use bucket name
sed -i "s/defaultBucketName/$workingDir/g" request.json

#************************************************************************************************************
#2. submit the batch (as defined in request.json) for predication

#load authorization service account credentials in case they timed out from previous loading
export GOOGLE_APPLICATION_CREDENTIALS="$sakAuthFileName"

runResults=$(curl -s -X POST \
-H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
-H "Content-Type: application/json; charset=utf-8" \
-d @request.json \
"https://automl.googleapis.com/v1/projects/$projectId/locations/us-central1/models/$modelId:batchPredict")

echo "*** JOB HAS STARTED and job JSON to environment variable runResults, current value:"
echo "$runResults" | jq .

#save the run results JSON to later reference
echo "$runResults" | jq . > jobDetails.json

#************************************************************************************************************
#3. job is now running. Now prepare an easy way to check on the job's completion and exam the predictions

#get job ID from job JSON:
iodName=$(jq -n --argjson data "$runResults" '$data.name')

#get start position of job id: IOD123456...
iodStart=$(awk -v a="$iodName" -v b="$IODLabel" 'BEGIN{print index(a,b)}')

iodLen=`expr length "$iodName"`
let "iodLen-=1" 
runningJobId=$(echo "$iodName" | cut -c$iodStart-$iodLen)

echo "running job id to environment variable runningJobId, current value:"
echo "$runningJobId"

#get the current status of the job and store resulting JSON in environment variable
runningStatus=$(curl -s -X GET \
-H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
https://automl.googleapis.com/v1/projects/$projectId/locations/us-central1/operations/$runningJobId)

echo "run status to variable: runningStatus, current value:"
echo $runningStatus | jq .

echo "$runningStatus" | jq . > jobStatus.json

#prepend file with script command for easy referencing later on
echo -e "~/./processResults.sh $runningJobId $workingDir\n\n$(cat jobStatus.json)" > jobStatus.json

echo "$runningJobId" > jobId.txt

#run the job that queries the job status now. Run this command later to check on the job's completion status.
echo "*** running processResults.sh: ***"
~/./processResults.sh $runningJobId $workingDir
echo ""

#echo the check on job's completion status command to the screen as well
echo "*** process results command:"
echo ./processResults.sh $runningJobId $workingDir
echo ""

echo "********** END OF SCRIPT **********"
