#!/usr/bin/env zsh

zmodload zsh/zutil || return

# This is a thin wrapper around rclone
# 
# Its purpose is to `rclone sync` the content of an existing folder
# (presumably holding backup files) to a remote location known by rclone.
#
# It can optionally mount/unmount a drive before/after the operation.
# You can give this script a path to a shellscript to be source'd to contain
# parameters for rclone 

RCLONE_BIN=$(which rclone)
CLOUDIFY_ENV_FILE=""
CLOUDIFY_SOURCE_MOUNTPOINT=""
CLOUDIFY_SOURCE_BASEDIR=""
CLOUDIFY_DEST_PATH=""

ERR=0

# functions
doBefore() {
  echo "======================================"
  echo "executing 'before' actions..."
  if [[ -f $CLOUDIFY_ENV_FILE ]]; then
    echo "- loading environment variables from '$CLOUDIFY_ENV_FILE'"
    source $CLOUDIFY_ENV_FILE
    ERR=$?
  fi
  if [[ $ERR -eq 0 && ! -z "$CLOUDIFY_SOURCE_MOUNTPOINT" ]]; then
    echo "- mounting "$CLOUDIFY_SOURCE_MOUNTPOINT
    mount $CLOUDIFY_SOURCE_MOUNTPOINT
    ERR=$?
  fi
}

doAfter() {
  echo "======================================"
  echo "executing 'after' actions..."
  if [ ! -z "$CLOUDIFY_SOURCE_MOUNTPOINT" ]; then
    echo "- unmounting "$CLOUDIFY_SOURCE_MOUNTPOINT
    umount $CLOUDIFY_SOURCE_MOUNTPOINT
    ERR=$?
  fi
}

doSync() {
  if [ $ERR -eq 0 ]; then
    echo "======================================"
    echo "starting sync..."
    $RCLONE_BIN sync --progress --checksum $CLOUDIFY_SOURCE_BASEDIR $CLOUDIFY_DEST_PATH
    ERR=$?
  fi
}

displayUsage() {
  SELF=`basename $1`
  echo "Usage: $SELF --source path/to/source --destination url://to/destination [options]"
  echo
  echo "Available options:"
  echo "  -s  --source        valid path or url for rclone to sync from"
  echo "  -d  --destination   valid rclone remote url to sync to"
  echo "  -e  --env-file      path to file with environment variables to be source'd"
  echo "  -m  --mountpoint    optional file path to mount/unmount before/after the sync"
  echo "  -y  --yes           don't confirm before syncing"
  exit 1
}

# parse input parameters
zparseopts -D -F -K --                  \
  {e,-env-file}:=env_file               \
  {d,-destination}:=dest_path           \
  {s,-source}:=source_path              \
  {m,-mountpoint}:=source_mountpoint    \
  {y,-yes}=noconfirm                    \
  || return

CLOUDIFY_ENV_FILE=${env_file[-1]}
CLOUDIFY_SOURCE_MOUNTPOINT=${source_mountpoint[-1]}
CLOUDIFY_SOURCE_BASEDIR=${source_path[-1]}
CLOUDIFY_DEST_PATH=${dest_path[-1]}
CLOUDIFY_NOCONFIRM=$#noconfirm

if [[ -z "$CLOUDIFY_SOURCE_BASEDIR" || -z "$CLOUDIFY_DEST_PATH" ]]; then
  displayUsage $0
fi

echo "======================================"
echo " source path       : "$CLOUDIFY_SOURCE_BASEDIR
echo " source mount point: "$CLOUDIFY_SOURCE_MOUNTPOINT
echo " destination       : "$CLOUDIFY_DEST_PATH
echo " env parameters    : "$CLOUDIFY_ENV_FILE
echo "--------------------------------------"

if [ $CLOUDIFY_NOCONFIRM -ne 1 ]; then
  read -q "CLOUDIFY_NOCONFIRM?start backup? [y/N]: "
fi
if [[ $CLOUDIFY_NOCONFIRM -eq 1 || $CLOUDIFY_NOCONFIRM = "y" ]]; then
  echo
  doBefore
  doSync
  doAfter
else
  echo
  echo "aborting"
fi

