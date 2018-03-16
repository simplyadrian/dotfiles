#! /bin/bash
for i in $(find $1 -type f -name '*.avi' -print0 | xargs -0 -n 1);
do
    avconv -y -i "$i" -vcodec libx264 -acodec aac -strict experimental -threads 3 "${i%.*}.mp4";
	rm "$i";
	chown $2 "${i%.*}.mp4";
done

for i in $(find $1 -type f -name '*.mkv' -print0 | xargs -0 -n 1);
do
    avconv -y -i "$i" -vcodec libx264 -acodec aac -strict experimental -threads 3 "${i%.*}.mp4";
	rm "$i";
	chown $2 "${i%.*}.mp4"
done
