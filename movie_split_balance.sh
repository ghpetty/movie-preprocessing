#! /bin/sh
# This script prepares a movie file for use with PsychoPy.
# It operates on a single video file, isolates the sound and video components,
# and saves them as separate files. 
# In the process it also:
# - Resizes the video to 1980x1020 resolution, adding a black border if necessary
# - Adjusts the audio file to have an integrated loudness of -17 LUF (mean volume of about -17 Hz)
# - Ensures the audio is sampled at 48kHz
# Outputs are stored in a new folder which is named after the input movie.

VERSION=0.1
display_help() {
	echo
	echo "Usage: movie_split_balance  <file.mp4>"
	echo
	echo "Options:"
	echo "  -h, -help       Show this help message and exit."
	echo "  -v, -version    Display script version" 
	echo "  -I <value>       Target integrated LUF value for audio balancing"
	echo "                   (default=-17, -70<I<-5)."
}
display_version() {
	echo "movie_split_balance version $VERSION"
	echo "Last tested with FFmpeg version 6.1"
}
LOUDNESS_I=-17
while getopts ":hvI:" opt; do
	case "${opt}" in
		h )
			display_help
			exit 0
			;;
		v ) 
			display_version
			exit 0
			;;
		I )
			LOUDNESS_I="$OPTARG"
			;;
		\? )
			echo "Invalid option: -${OPTARG}" >&2
			display_help
			exit 1
 			;;
	esac
done

# Check loudness parameter
if (( $LOUDNESS_I > -5 || $LOUDNESS_I < -70)); then
	echo "Error: Invalid I value. I must be in range -70<L<-5"
	exit 1
fi
shift $((OPTIND -1))


INPUTFILE="$1"

if [ ! -f "$INPUTFILE" ]; then
  echo "Error: File '$INPUTFILE' does not exist."
  exit 1
fi
# if  echo $INPUTFILE | grep -qv '.mp4$' ; then
# 	echo "Error: expected input to be an MP4 file"
# 	exit 1
# fi
FILENAME_BASE=$(basename ${INPUTFILE})
DIR=$(dirname ${INPUTFILE}) 
FILENAME_BASE=${FILENAME_BASE%.mov}
FILENAME_BASE=${FILENAME_BASE%.mp4}
OUTPUT_DIR=$DIR"/"$FILENAME_BASE
echo "$OUTPUT_DIR"
if [ ! -d "$OUTPUT_DIR" ]; then
	mkdir "$OUTPUT_DIR"
fi
AUDIOFILEOUT=$FILENAME_BASE"_audio.mp3"
# echo $AUDIOFILEOUT
VIDEOFILEOUT=$FILENAME_BASE"_video.mp4"
MEASUREMENTSFILE=$FILENAME_BASE"_loudness.txt"
# Measure loudness, save output to file, then load pertinent information from file
echo "Measuring loudness..."
echo "$FILENAME_BASE/$MEASUREMENTSFILE"
ffmpeg -i "$INPUTFILE" -af loudnorm=I="$LOUDNESS_I":print_format=summary -vn -nostats -f null - 2>"$OUTPUT_DIR/$MEASUREMENTSFILE"
while IFS= read -r line; do
	if [[ $line =~ "Input " ]]; then
		echo $line
	fi
	if [[ $line =~ "Input Integrated" ]]; then
		INPUTINTEGRATED=$(echo "$line" | grep -oE '(\-?)([0-9]+([.][0-9]+)?)')
	fi
	if [[ $line =~ "Input True Peak" ]]; then
		INPUTTRUEPEAK=$(echo "$line" | grep -oE '(\-?)([0-9]+([.][0-9]+)?)')
	fi
	if [[ $line =~ "Input LRA" ]]; then
		INPUTLRA=$(echo "$line" | grep -oE '(\-?)([0-9]+([.][0-9]+)?)')
	fi
	if [[ $line =~ "Input Threshold" ]]; then
		INPUTTHRESHOLD=$(echo "$line" | grep -oE '(\-?)([0-9]+([.][0-9]+)?)')
	fi	
done < "$OUTPUT_DIR/$MEASUREMENTSFILE"

# Extract and balance audio from video
ffmpeg -y -i "$INPUTFILE" -af \
loudnorm=I="$LOUDNESS_I":measured_I="$INPUTINTEGRATED":measured_LRA="$INPUTLRA":measured_TP="$INPUTTRUEPEAK":\
measured_thresh="$INPUTTHRESHOLD":linear=true -ar 48000 "$OUTPUT_DIR/$AUDIOFILEOUT"

# Resize the video (adding border if necessary) and remove sound
ffmpeg -y -i "$INPUTFILE" -filter_complex "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black" \
-c:v libx264 -crf 23 -preset slow -an "$OUTPUT_DIR/$VIDEOFILEOUT"


