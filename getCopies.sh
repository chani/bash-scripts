#!/bin/bash
#####################################################################
##                                                                 ##
##     getCopies v0.1                                              ##
##     this script can be used to find copies of files             ##
##                                                                 ##
#####################################################################

#####################################################################
##                                                                 ##
##    Author:    Jean-Michel Bruenn <himself@jeanbruenn.info>      ##
##    Copyright: 2008-2018                                         ##
##    License:   MIT (see LICENSE file)                            ##
##                                                                 ##
#####################################################################

# Possible values are sha1sum and md5sum
C_METHOD="md5sum";
# where to search for data
C_DIRECTORY="$1";
# where to move copies (will automatically create directory "copies")
W_DIR="$2";

# ----------------------------------------------------------------- #
# No need to touch anything below this line                         #
# ----------------------------------------------------------------- #

cnv_filename() {
  # get ending from file (ending)
  ENDING=$(echo "$@" | sed -r 's|.*/||' | sed -r 's|.*\.||');
  # get name from file (filename)
  BEFORE=$(echo "$@" | sed -r 's|.*/||' | sed -r 's|\..*||');

  if [ -f "$W_DIR"/copies/"$BEFORE"."$ENDING" ] ; then
    # file exists let's add a number to the filename
    # and check whether that file exists too (we set
    # this number higher until we found a not existing
    # filename.
    echo "+ Copy detected" >&2

    for (( I=1; $I <= 999; I++ )) ; do
      if [ ! -f "$W_DIR"/copies/"$BEFORE"."$I"."$ENDING" ] ; then
        # wow, we got a free filename. Let's break the
        # for and give back the new filename
        D_NAME="$BEFORE"."$I"."$ENDING";
        break;
      fi
    done
    echo "+ Renamed to: $BEFORE.$I.$ENDING" >&2
  else
    # the filename is free already.
    D_NAME="$BEFORE"."$ENDING";
  fi
}

echo "+ getting file list" >&2
W_FILES=$(find "$C_DIRECTORY" -type f);

if [ -f /tmp/getCopies.txt ] ; then
  rm -rf /tmp/getCopies.txt
  echo "+ deleted /tmp/getCopies.txt" >&2
fi

echo "+ generating sums" >&2

IFS=$'\n';
for FILENAME in $W_FILES; do
  if [[ "$C_METHOD" == "sha1sum" ]] ; then
    # user wanted sha1sums
    SUM=$(sha1sum "$FILENAME" | sed 's| .*||');
  elif [[ "$C_METHOD" == "md5sum" ]] ; then
    # user wanted md5sums
    SUM=$(md5sum "$FILENAME" | sed 's| .*||');
  else
    # sum not recognized
    echo "You have to set C_METHOD to a correct value!";
    exit 0
  fi

  TOADD="$FILENAME:$SUM";
  echo "$TOADD" >> /tmp/getCopies.txt
  echo "+ added $TOADD" >&2
done

FILECOUNT=$(echo "$W_FILES" | wc -w);

echo "+ processed $FILECOUNT files" >&2

mkdir -v "$W_DIR/copies";

E_FILES=$(sort -nr /tmp/getCopies.txt);

IFS=$'\n';
for LINE in $E_FILES; do
  F_NAME=$(echo "$LINE" | sed -r 's|:.*||');
  F_SUM=$(echo "$LINE" | sed -r 's|.*:||');
  F_SUMS=$(grep "$F_SUM" /tmp/getCopies.txt | wc -l);

  if [[ "$F_SUMS" -eq "1" ]] || [[ "$F_SUMS" -eq "0" ]] ; then
    # no copy detected
    continue;
  else
    # wow - copy detected
    D_NAME=$(echo "$F_NAME" | sed 's|.*/||');
    echo "+ detected $F_SUMS copies of $D_NAME" >&2
    COPIES="$COPIES $D_NAME";
    echo "+ moving $D_NAME to $W_DIR/copies/$D_NAME" >&2
    # lets make sure not to overwrite anything.
    cnv_filename "$F_NAME"
    # now lets move the file to our copies folder.
    mv "$F_NAME" "$W_DIR/copies/$D_NAME";
    # now we need to remove this line from /tmp/getCopies.txt
    # otherwise it will result in false positives.
    sed -i 's|'$F_NAME':'$F_SUM'||' /tmp/getCopies.txt
  fi
done

COPYCOUNT=$(echo "$COPIES" | wc -w);
echo "+ moved $COPYCOUNT copies";
