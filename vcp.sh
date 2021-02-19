#!/bin/bash

# Things To Do:
#
#  o Allow optional ffmpeg options before STARTTIME.

ME="${0##*/}"

usage()
{
	cat >&2 <<-EOF
	usage: $ME [ --scale WIDTH:HEIGHT ] [ --aspect X:Y ] START END INFILE OUTFILE

	Copies part of video file INFILE to OUTFILE, starting at time START, and ending at
	time END.  Only one video and one audio stream is copied (see the ffmpeg docs for
	how it chooses the streams, but ffmpeg defaults to the highest quality streams).

	START/END have the format [HH:][MM:]SS[.s...], where HH is hours, MM is
	minutes, SS is seconds, and s is a decimal fraction of a second.  If
	STARTTIME/ENDTIME is '-', the actual start/end (respectively) time of the
	video is used.

	--aspect  =>  Sets the aspect ratio at the container level.  Does not
	              transcode video.

	--scale   =>  Scales video to new WIDTH and HEIGHT (in pixels) without
	              changing the aspect ratio.  NOTE: This transcodes the video!

	Examples:

	  $ME 0 10 in.mkv out.mkv       # Copy the first 10 seconds.
	  $ME 1:00 - in.mkv out.mkv     # Copy from 1 minute to the end.
	  $ME 2:30 4:15 in.mkv out.mkv  # Copy from 2m 30s to 4m 15s.
	  $ME - 3:00 in.mkv out.mkv     # Copy from the start to 3 minutes.
	EOF

	exit 1
}

###############################################################################################
# Parse command line.

unset START END INFILE OUTFILE VIDOPTS SCALE ASPECT

while [[ $# -gt 0 ]]
do
	case "$1" in
	--scale | -s)	[[ $# -lt 5 ]] && usage
			SCALE="$2"
			shift
			;;

	--aspect | -a)	[[ $# -lt 5 ]] && usage
			ASPECT="$2"
			shift
			;;

	*)		break ;;  # Stop at first non-switch.

	-*)		usage ;;
	esac

	shift
done

[[ $# -ne 4 ]] && usage

START="$1"
END="$2"
INFILE="$3"
OUTFILE="$4"

[[ "$START" = "-" ]] && START=0
[[ "$END" = "-" ]] && END=999999  # ~277 hours, which is effectively infinity.

if [[ ! "$START" =~ ^([0-9]+:)?([0-9]+:)?[0-9]+(\.[0-9]+)?$ ]]
then
	echo "$ME: Invalid start time: '$START'!" >&2
	echo >&2
	usage
fi

if [[ ! "$END" =~ ^([0-9]+:)?([0-9]+:)?[0-9]+(\.[0-9]+)?$ ]]
then
	echo "$ME: Invalid end time: '$END'!" >&2
	echo >&2
	usage
fi

if [[ -n "$SCALE" ]]
then
	if [[ ! "$SCALE" =~ ^[0-9]+:[0-9]+$ ]]
	then
		echo "$ME: Invalid SCALE value: '$SCALE'!" >&2
		echo >&2
		usage
	fi

	VIDOPTS="-vf scale=$SCALE"
else
	VIDOPTS="-codec copy"
fi

if [[ -n "$ASPECT" ]]
then
	if [[ ! "$ASPECT" =~ ^[0-9]+:[0-9]+$ ]]
	then
		echo "$ME: Invalid ASPECT value: '$ASPECT'!" >&2
		echo >&2
		usage
	fi

	VIDOPTS+=" -aspect $ASPECT"
fi

###############################################################################################
# Sanity checks.

if [[ ! -f "$INFILE" ]]
then
	echo "$ME: File not found: '$INFILE'!" >&2
	exit 1
fi

if [[ -f "$OUTFILE" ]]
then
	echo "$ME: Output file exists: '$OUTFILE'!" >&2
	read -p "Overwrite? (y/n) " ANS
	[[ "$ANS" != "y" ]] && exit 1

	rm "$OUTFILE"
fi

###############################################################################################
# Copy video.

ffmpeg -accurate_seek -ss "$START"  -to "$END" -i "$INFILE" $VIDOPTS "$OUTFILE"

exit "$?"

