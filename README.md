# gcpGoogleCloudAutoMLVisionScripts

John Carmichael wrote some GCP Google Cloud AutoML Vision Scripts for batch prediction / object detection in online videos

Experimenting with GCP Google Cloud AutoML Vision I found that AutoML does pretty much all heavy lifting of object identitification. Hurray! My idea was to try it out with images generated as individual frames from videos. The most convenient source of videos was online ones (eg: Youtube). I trained a model with some Where's Waldo pictures and then ran the frames from some videos from Youtube featuring people dressed as Waldo as a AutoML Prediction job.

Or potentially identifying/finding products in videos. Any ideas along that sort of line with an easily identitifiable subject type and then you could script in as many videos as your wanted for analysis.

There was still a fair amount of leg work to make batch prediction work from a video URL and examine the results. These scripts automate these processes.

runlogicinstall.sh - run this script for the first time after starting your Google Cloud Shell in order to complete the additional steps of installing FFMpeg, etc first.

runlogic.sh - run this script to launch a Google AutoML Vision prediction (object identification) job for your specified video. Launches prediction job consisting of frame images from a specified video. Script creates frames images from video, creates job request.json file, creates bucket, moves images to bucket, creates batch_prediction.csv file, and so on all the way through to submitting the job.

processResults.sh - run this script to easily see the completion status of your job and if the job is completed then it will process the job results into a more readily usable format.

vcp.sh - this can be used to easily copy part of a video outputting a new video with a simple command and without having to know FFMpeg commands (I didn't write this script)

Anyways, thrown together pretty quick but it works. Prediction was fairly good for medium and large sized subjects, smaller ones need more work.

No guarantees whatsoever, use at your own risk.
