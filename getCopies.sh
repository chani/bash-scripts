#!/bin/bash
#####################################################################
##                                                                 ##
##     getCopies v0.2                                              ##
##     this script can be used to find copies of files             ##
##                                                                 ##
#####################################################################

#####################################################################
##                                                                 ##
##    Author:    Jean-Michel Bruenn <himself@jeanbruenn.info>      ##
##    Copyright: 2008-2024                                         ##
##    License:   MIT (see LICENSE file)                            ##
##                                                                 ##
#####################################################################

#date +%s > start.txt

# Checksum command. 
# e.g. md5sum, sha1sum, cksum -a sha224, rhash --md4 --simple
C_CHECKSUM="sha1sum"

# Where to search for duplicates
P_SRC="$1"
# Where to move duplicates to
P_DST="$2/copies"

# how many bytes to read from start of file for partial checksum (to
# speed up processing). Smaller values do not necessarily make it
# faster - because e.g. a value of 20 will cause more files to be
# checked with a full hash (which then is slow).
S_PART=4096

# The follwoing three files would be best on tmpfs
F_CHECKSUMS="/tmp/getCopies.txt"
F_SIZES="/tmp/getCopies.sizes.txt"
F_PARTIAL="/tmp/getCopies.partial.txt"

cnv_filename() {
  local fullname=$(basename -- "$@")
  local extension="${fullname##*.}"
  local filename="${fullname%.*}"
  local i=1
  local re='^[0-9]+$'

  if [ -f "${P_DST}"/"${fullname}" ]; then
    if [[ ${extension} =~ ${re} ]]; then 
      i=${extension}
    fi
    D_NAME="${filename}"."$i";
    while [ -f "${P_DST}"/"${D_NAME}" ]; do
      ((i=i+1))
      D_NAME="${filename}"."$i";
      sleep 0.01
    done
    echo "+ Renamed to: ${D_NAME}" >&2
  fi
}

if [ ! -d "${P_DST}" ]; then
  mkdir -p "${P_DST}"
fi
if [ -f "${F_CHECKSUMS}" ]; then
  truncate -s0 "${F_CHECKSUMS}"
fi
touch "${F_CHECKSUMS}"
if [ -f "${F_SIZES}" ]; then
  truncate -s0 "${F_SIZES}";
fi
touch "${F_SIZES}"
if [ -f "${F_PARTIAL}" ]; then
  truncate -s0 "${F_PARTIAL}"
fi
touch "${F_PARTIAL}"

exec 5>> "${F_CHECKSUMS}"
exec 4>> "${F_PARTIAL}"
exec 3>> "${F_SIZES}"

PROCESSED=0
COPIES=0

while read -r FILENAME; do
  SIZE=$(stat --printf=%s "${FILENAME}");
  if lh=$(LC_ALL=C grep -F -m1 "|${SIZE}" "${F_SIZES}"); then
    echo "+ Duplicate candidate detected (By size)..."
    
    # each size exists only once in sizes file. So if it finds a duplicate
    # size also it's partial hash needs to be created
    LFILENAME="${lh%|*}"
    LPSUM=$({ head -c ${S_PART} "${LFILENAME}"; } | ${C_CHECKSUM})
    LPSUM=${LPSUM% *}

    if ! $(LC_ALL=C grep -F -q -m1 "|${LPSUM}" "${F_PARTIAL}"); then
      echo "+ Added (partial checksum): ${LPSUM}"
      echo "${LFILENAME}|${LPSUM}" >&4
    fi

    PSUM=$({ head -c ${S_PART} "${FILENAME}"; } | ${C_CHECKSUM})
    PSUM=${PSUM% *}
    if fh=$(LC_ALL=C grep -F -m1 "|${PSUM}" "${F_PARTIAL}"); then
      echo "+ Duplicate candidate detected (By partial checksum)..."

      # each partial hash exists only once in partial file. So if it finds a
      # duplicate partial hash it's full hash needs to be created, too
      FFILENAME="${fh%|*}"
      FFSUM=$(${C_CHECKSUM} "${FFILENAME}");
      FFSUM=${FFSUM% *}
      if ! $(LC_ALL=C grep -F -q -m1 "|${FFSUM}" "${F_CHECKSUMS}"); then
	echo "+ Added (${C_CHECKSUM}): ${FFSUM}"
	echo "${FFILENAME}|${FFSUM}" >&5
      fi

      SUM=$(${C_CHECKSUM} "${FILENAME}");
      SUM=${SUM% *}
      if ! $(LC_ALL=C grep -F -q -m1 "|${SUM}" "${F_CHECKSUMS}"); then
        # no copy detected - add
        echo "+ Added (${C_CHECKSUM}): ${SUM}"
	echo "${FILENAME}|${SUM}" >&5
      else
        # duplicate detected 
	D_NAME="${FILENAME##*/}"
	echo "+ Duplicate detected (By ${C_CHECKSUM})..." >&2
        echo "+ Moving ${D_NAME} to ${P_DST}/${D_NAME}" >&2
        # lets make sure not to overwrite anything.
        cnv_filename "${D_NAME}"
        # now lets move the file to our copies folder.
        mv "${FILENAME}" "${P_DST}/${D_NAME}";
        ((COPIES=COPIES+1))
      fi
    else
      echo "+ Added (partial checksum): ${PSUM}"
      echo "${FILENAME}|${PSUM}" >&4
    fi
  else
    echo "+ Added (size): ${SIZE}"
    echo "${FILENAME}|${SIZE}" >&3
  fi
  ((PROCESSED=PROCESSED+1))
done< <(find "${P_SRC}" -type f)

echo "+ Moved ${COPIES} copies of ${PROCESSED} files";

#ate +%s > end.txt
