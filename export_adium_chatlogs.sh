#!/bin/bash

# Export Adium Chat Log
#
# Purpose: Convert Adium chat logs to another format using 'xsltproc'
# Usage: "export_adium_chatlogs.sh LOG -s STYLESHEET"
# Help: Run "export_adium_chatlogs.sh --help" for documentation
# Recommended width:
# |----------------------------------------------------------------------------|

# Set the field separator to a newline to allow spaces in file paths
IFS="
"

### Global Declarations ###
HELP=false
INPUT=
OUTPUT=
STYLESHEET=
DTD=
MODE=1
TESTMODE=false
SINGLE=false
CONVNUM=0
CONVSUFFIX=
AVAILPATH=
SCRIPTDIR=$(cd $(dirname $0); pwd)
TESTLOG=$SCRIPTDIR/adium-export-dry-run.txt


### Utility Functions ###
# Checks to see if path passed in is taken; if so, it attempts to add " 1" to
# " 99" to the path, and passes back the first available path that is found,
# using global AVAILPATH; function will exit script if no available path is
# found
function checkForPathConflict()
{
  isFile=

  if ! [ -a "$1" ]; then
    AVAILPATH="$1"
    return
  elif [ -f "$1" ]; then
    isFile=true
  elif [ -d "$1" ]; then
    isFile=false
  else
    echo "Error: Encountered something that is not a file or directory: $1."
    exit 56
  fi

  ct=0
  AVAILPATH="$1"
  until [ $ct -eq 100 ]
  do
    if [ -a "$AVAILPATH" ]; then
      let ct+=1
      # If this is a file, and it has a suffix, break the name up at the period
      # so we can insert the unique number at the end of the name and not the
      # suffix
      if $isFile && [[ $1 == *.* ]]; then
        preDot=${1%.*}
        postDot=${1##*.}
        AVAILPATH="$preDot $ct.$postDot"
      else
        AVAILPATH="$1 $ct"
      fi
    else
      break
    fi
  done
  if [ $ct -eq 100 ]; then
    # Just quit, because something is probably wrong
    echo "Error: Cannot find a place in $(dirname $1) for $(basename $1)."
    exit 57
  fi
}

# Makes a path absolute; used as a safeguard on paths passed into script by user
function makeAbsPath()
{
  if [ -a $1 ]; then
    # If it begins with "/", then it's already an absolute path
    if [[ $1 == /* ]]; then
      ABSPATH=$1
    # If it's a directory, 'pwd' the full path into ABSPATH
    elif [ -d $1 ]; then
      ABSPATH=$(cd $1; pwd)
    # If it's a file, get the full parent path and add the file name onto it
    elif [ -f $1 ]; then
      ABSPATH=$(cd $(dirname $1); pwd)
      ABSPATH=$ABSPATH/$(basename $1)
    fi
  else
    echo "Error: Could not find file or directory \"$1\"."
    exit 58
  fi
}

# Abstracts calling of 'xsltproc', so that we can centrally disable it in
# testing mode, and to handle any error codes that it may return. Pass in the
# input path as first argument and the output path second.
function runXSLT()
{
  theCall="xsltproc --nonet"

  # Just for safety's sake, since neither of these cases requires any new dir.s
  if $SINGLE || [ $MODE -eq 2 ]; then
    theCall="$theCall --nomkdir"
  fi

  # Assume that there is an XML file in the .chatlog we were passed
  XMLPATH="$1/$(basename $1 .chatlog).xml"

  theCall="$theCall -o \"$2\" \"$STYLESHEET\" \"$XMLPATH\""

  if $TESTMODE; then
    echo $theCall >> "$TESTLOG"
  else
    eval $theCall
    theError=$?
    if [ $theError -ne 0 ]; then
      if [ $theError -eq 1 ]; then
        echo "Error: xsltproc failed with error code 1: No argument"
      elif [ $theError -eq 2 ]; then
        echo "Error: xsltproc failed with error code 2: Too many parameters"
      elif [ $theError -eq 3 ]; then
        echo "Error: xsltproc failed with error code 3: Unknown option"
      elif [ $theError -eq 4 ]; then
        echo "Error: xsltproc failed with error code 4: Failed to parse the stylesheet"
      elif [ $theError -eq 5 ]; then
        echo "Error: xsltproc failed with error code 5: Error in the stylesheet"
      elif [ $theError -eq 6 ]; then
        echo "Error: xsltproc failed with error code 6: Error in one of the documents"
      elif [ $theError -eq 7 ]; then
        echo "Error: xsltproc failed with error code 7: Unsupported xsl:output method"
      elif [ $theError -eq 8 ]; then
        echo "Error: xsltproc failed with error code 8: String parameter contains both quote and double-quotes"
      elif [ $theError -eq 9 ]; then
        echo "Error: xsltproc failed with error code 9: Internal processing error"
      elif [ $theError -eq 10 ]; then
        echo "Error: xsltproc failed with error code 10: Processing was stopped by a terminating message"
      elif [ $theError -eq 11 ]; then
        echo "Error: xsltproc failed with error code 11: Could not write the result to the output file"
      else
        # We may get here if the actual attempt to call xsltproc failed
        echo "Error: xsltproc failed with unknown error or could not be called."
        theError=49
      fi
      echo "The log being processed was $1."
      # If there are more files, ask the user if they want to continue
      if ! $SINGLE; then
        a="a"
        until [ $a == "y" ]
        do
          echo "Would you like to continue processing log files? (y/n)"
          read a
          if [ $a == "n" ]; then
            echo "Goodbye."
            exit $theError
          elif [ $a != "y" ]; then
            echo "I'm sorry, I didn't get that. Type 'y' to continue or 'n' to quit."
          fi
        done
      fi
    fi
  fi
}

# Output nested in function so it can be piped to 'less' for paging
function printHelp()
{
  cat << EOF

NAME
       Export Adium Chat Logs v1.0

SYNOPSIS
       export_adium_chatlogs.sh [-h | --help]
       export_adium_chatlogs.sh input [-o | --output] [-s | --stylesheet path]
          [-d | --dtd path] [[-f | --flat ] | [-s | --intersperse ] |
          [-m | --mirror]] [-t | --test-mode]

DESCRIPTION
       This script uses 'xsltproc' to parse Adium's chat log files and save them
       in the format specified by a separate stylesheet.

       You must pass this script as its first argument a directory that
       contains .chatlogs or a single .chatlog, and provide the path to the
       stylesheet of your choice using the -s option. All other arguments are
       optional, however if a file called chatlog.dtd is not present next to the
       script, you need to specify the path with the -d option, or else the
       script will quit without doing any work.

       Converted logs will be placed in a folder called "Converted logs",
       surprisingly enough, which is located at the same level as the folder you
       pass in for conversion (or at the location you specify with the -o
       option). If you pass in a single .chatlog instead of a folder, the script
       simply places the converted log next to the original log by default.

SAFETY
       This script has two constructive disk-write calls in it (1 mkdir, 1
       xsltproc) and no destructive calls except the one that clears the
       script's log in testing mode (echo >). Run the script with normal options
       plus the "-t" option to get "dry-run" results; the disk-write lines will
       instead echo to a log file called "adium-export-dry-run.txt". This test
       mode will not run 'xsltproc', so it cannot predict a failure in that part
       of the process.

OUTPUT MODES
       This script can output its converted chat logs in one of three ways:
       Directory-mirrored (default, --mirror, -m)
       Interspersed (--intersperse, -i)
       Flat folder (--flat, -f)

       Let's look at flat-folder mode first. Say that you run the script this
       way (these examples leave out the required -s option for brevity):
       export_adium_chatlogs.sh "/Users/you/Documents/Chat logs/" --flat

       ...and let's call that path CHATLOGS for short. Running the script in
       flat-folder mode will simply take every .chatlog it finds recursively in
       CHATLOGS and dump the converted chat logs directly inside "Converted
       logs". Files will be renamed as necessary to avoid name conflicts, since
       multiple sub-folders may be getting combined into "Converted logs".

       Now let's say you run the script this way:
       export_adium_chatlogs.sh "/Users/you/Documents/Chat logs/" --intersperse

       Each converted chat log is simply placed next to the .chatlog file that
       was converted, in the original folder provided as input.

       If you run the script normally, it's the same as using --mirror:
       export_adium_chatlogs.sh "/Users/you/Documents/Chat logs/"

       Directory mirroring prevents you from losing any tree structure of
       folders which you or Adium may have used to organize your original chat
       logs. So, if you pass the script the path CHATLOGS, and CHATLOGS has a
       structure like this:

       CHATLOGS
         FOLDER 1
           File 1.txt
           SUBFOLDER 1
             File 2.txt
         FOLDER 2
           myfriend (2011-11-18T12.55.04-0400).chatlog
         FOLDER 3
           SUBFOLDER 2
             myparent (2011-11-18T18.09.36-0400).chatlog

       You will get this structure created in the output directory (suffixes are
       just an example):

       CHATLOGS
         FOLDER 2
           myfriend (2011-11-18T12.55.04-0400).rtf
         FOLDER 3
           SUBFOLDER 2
             myparent (2011-11-18T12.55.04-0400).rtf

       FOLDER 1 was passed over because it contained no .chatlogs in it or its
       sub-folder. FOLDER 3 will be created just in order to contain SUBFOLDER
       2, which had a .chatlog in it.


OPTIONS
       -h/--help        Show this message
       -o/--output      Place "Converted logs" at specified path
       -s/--stylesheet  Use .xsl file at specified path (required)
       -d/--dtd         Use .dtd file at specified path
       -m/--mirror      Default behavior unless -i or -f invoked; use directory
                        mirroring (see OUTPUT MODES section above for details)
       -i/--intersperse Place converted chat logs next to original files
       -f/--flat        Place converted chat logs all in one folder
       -t/--test-mode   Instead of performing actions, write to log what actions
                        would be performed

BUGS
       The script may malfunction if the user provides it a path to anything
       that is not a file or directory (e.g. a device file or symlink).
EOF
}


### Main Script ###
## Argument Handling ##
# If first argument is a help request, or if nothing was passed in at all, then
# print help and quit, or else get the input path and continue
if [ "$#" -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  printHelp | less
  exit 0
else
  INPUT=$1
  shift
fi

# Parse for short/long options as long as there are more arguments to process
while (( "$#" ))
do
  case "$1" in
    -o | --output )       OUTPUT="$2";     shift 2;;
    -s | --stylesheet )   STYLESHEET="$2"; shift 2;;
    -d | --dtd )          DTD="$2";        shift 2;;
    -m | --mirror )       MODE=1;          shift;;
    -i | --intersperse )  MODE=2;          shift;;
    -f | --flat )         MODE=3;          shift;;
    -t | --test-mode )    TESTMODE=true;   shift;;
    * )                   echo "Error: Invalid argument detected."; exit 51;;
  esac
done

if $TESTMODE; then
  echo -n "" > $TESTLOG
fi

## Variable Setup ##
# Make path absolute in case it is relative
makeAbsPath "$INPUT"
INPUT="$ABSPATH"
#INPUT=$(`cd $(dirname $INPUT); pwd`)/$(basename $INPUT)

# If OUTPUT is not set, set it to location of INPUT's parent folder
# If we are in intersperse mode, OUTPUT will not be used
if [ -z $OUTPUT ]; then
  OUTPUT=$(dirname $INPUT)
else
  # User wasn't supposed to specify an output location with intersperse mode, so
  # warn them and quit, because otherwise when we ignore OUTPUT later, we won't
  # be operating in the way that the user expects
  if [ $MODE -eq 2 ]; then
    echo "Error: You aren't supposed to specify an output location with '-i' because intersperse mode automatically places exported logs next to the original .chatlogs. Please run script again without the '-o' argument."
    exit 52
  fi
fi

makeAbsPath "$OUTPUT"
OUTPUT="$ABSPATH"

# If INPUT is actually a folder and not a .chatlog package, construct the output
# folder's name, otherwise flag that we are dealing with a single file
if ! [ ${INPUT##*.} == chatlog ] && ! [ ${INPUT##*.} == chatlog/ ]; then
  OUTPUT="$OUTPUT/Converted logs"
else
  SINGLE=true
fi

# If INPUT is not a valid folder or .chatlog package, quit
if ! [ -d "$INPUT" ]; then
  echo "Error: The path $INPUT is not a valid folder or .chatlog."
  exit 53
fi

makeAbsPath "$STYLESHEET"
STYLESHEET="$ABSPATH"

# If STYLESHEET is not set, quit, otherwise extract the suffix from the name of
# the .xsl file
if ! [ -f "$STYLESHEET" ]; then
  echo "Error: No stylesheet supplied with '-s'."
  exit 54
else
  CONVSUFFIX=${STYLESHEET##*format-}
  CONVSUFFIX=${CONVSUFFIX%%.xsl}
  # If we got a suffix that is empty or more than 5 characters, perhaps the .xsl
  # was not named as expected, so just plug in a generic suffix to prevent any
  # major errors later in code
  if [ "${#CONVSUFFIX}" -gt 5 ] || [ "${#CONVSUFFIX}" -lt 1 ]; then
    CONVSUFFIX="txt"
  fi
fi

# If DTD is not set, attempt to find it, otherwise quit
if [ -z $DTD ]; then
  DTD="$SCRIPTDIR/chatlog.dtd"
else
  makeAbsPath "$DTD"
  DTD="$ABSPATH"
fi
if ! [ -f "$DTD" ]; then
  echo "Error: No DTD found next to script that is called 'chatlog.dtd'; please supply the path to this file with '-d'."
  exit 55
fi

# Check for 'xsltproc', quit if not present
if ! [ `which xsltproc` ]; then
  echo "Error: xsltproc is not installed on this machine."
  exit 50
fi

## Folder Setup ##
# If we aren't converting just one chatlog, and we aren't in intersperse mode,
# then we need a "Converted logs" folder, so make one
if ! $SINGLE && ! [ $MODE -eq 2 ]; then
  checkForPathConflict "$OUTPUT"
  if ! $TESTMODE; then
    mkdir "$AVAILPATH"
    if [ $? -ne 0 ]; then
      echo "Error: Could not create folder $AVAILPATH."
      exit 59
    fi
  else
    echo "mkdir" "$AVAILPATH" >> "$TESTLOG"
  fi
  OUTPUT=$AVAILPATH
fi

## Log Conversion ##
# If we only have one file, then we simply pass it to 'xsltproc' and we're done
if $SINGLE; then
  # Our output name is OUTPUT plus the name of the .chatlog, but with the suffix
  # replaced
  desiredFilePath="$OUTPUT/$(basename $INPUT .chatlog).$CONVSUFFIX"
  checkForPathConflict "$desiredFilePath"
  runXSLT "$INPUT" "$AVAILPATH"
  CONVNUM=1
else
  # If we're in mirroring mode, cycle through dir.s in INPUT, and pass
  # 'xsltproc' any .chatlogs we find ('xsltproc' makes the corresponding
  # sub-dir.s in OUTPUT automatically); no need to check for path conflicts, as
  # 'xsltproc' will be creating new folders
  if [ $MODE -eq 1 ]; then
    for eachLog in `find $INPUT -type d -name "*.chatlog"`
    do
      # Convert eachLog's absolute path to one that is relative to the INPUT
      # directory, so we can mirror it in the OUTPUT directory
      desiredFilePath="${eachLog#$INPUT/}"
      desiredFilePath="$OUTPUT/${desiredFilePath%.chatlog}.$CONVSUFFIX"
      runXSLT "$eachLog" "$desiredFilePath"
      let CONVNUM+=1
    done
  # If we're in intersperse mode...
  elif [ $MODE -eq 2 ]; then
    for eachLog in `find $INPUT -type d -name "*.chatlog"`
    do
      # Strip eachLog's file name from its base path
      desiredFilePath="$eachLog/../$(basename $eachLog .chatlog).$CONVSUFFIX"
      checkForPathConflict "$desiredFilePath"
      runXSLT "$eachLog" "$AVAILPATH"
      let CONVNUM+=1
    done
  # If we're in flat-folder mode...
  elif [ $MODE -eq 3 ]; then
    for eachLog in `find $INPUT -type d -name "*.chatlog"`
    do
      desiredFilePath="$OUTPUT/$(basename $eachLog .chatlog).$CONVSUFFIX"
      checkForPathConflict "$desiredFilePath"
      runXSLT "$eachLog" "$AVAILPATH"
      let CONVNUM+=1
    done
  fi
fi

if ! $SINGLE; then
  echo "$CONVNUM chat logs were found and converted."
fi

exit 0