#!/bin/bash
#
# script runlogicinstall.sh
# date:  Feb 18, 2021
# usage: ./runlogicinstall.sh YouTubeVideoUrl GCPVisionModelId
# reference: https://cloud.google.com/vision/automl/docs/quickstart
# note:  if FFmpeg, etc need to be installed run this script, otherwise use runlogic.sh script  

#do a cloud bucket ls operation so the authorize window will come up first thing - enhancement: avoid in code somehow
gsutil ls

sudo apt-get update && sudo apt-get install -y ffmpeg
sudo -H pip3 install --upgrade youtube-dl
sudo apt-get install jq

./runlogic.sh %1 %2
