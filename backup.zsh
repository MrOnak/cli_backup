#!/usr/bin/env zsh

zmodload zsh/zutil || return

# This is a flexible wrapper around duplicity backups
#
# Its purpose is to combine some of the common duplicity commands like
# backup, verify and prune and wrap them in before/after actions
#
# You can supply an environment variable file that contains GPG passphrases and
# such to run backups non-interactively
# The wrapper can also mount/unmount before/after the backup itself.
#
# A the moment not all parameters are accessible through commandline parameters,
# do check the header of the script

DUP_BIN=$(which duplicity)
DUP_SOURCE_BASE=/
DUP_BACKUP_FORCE_FULL_AFTER=1M
DUP_BACKUP_PRUNE_EXEMPT_COUNT=2
DUP_BACKUPGROUP_INCLUDES=""
DUP_BACKUPTARGET_MOUNTPOINT=""
DUP_BACKUPTARGET_BASEDIR=""

ERR=0

# do some things before the backup
queryGPGInfo() {
  if [ $ERR -eq 0 ]; then
    if [[ -f $DUP_ENV_FILE ]]; then
      echo "loading environment variables from '$DUP_ENV_FILE'"
      source $DUP_ENV_FILE
    fi
    if [ -z "$DUP_KEY" ]; then 
      read -s -r "DUP_KEY?enter gpg key id: "
      echo
    fi
    if [ -z "$PASSPHRASE" ]; then
      read -s -r "PASSPHRASE?enter gpg passphrase for duplicity: "
      export PASSPHRASE
      echo
    fi
  fi
}

doBefore() {
  if [ $ERR -eq 0 ]; then
    echo "=============================="
    echo "executing 'before' actions..."
    if [ ! -z "$DUP_BACKUPTARGET_MOUNTPOINT" ]; then
      echo "- mounting "$DUP_BACKUPTARGET_MOUNTPOINT
      mount $DUP_BACKUPTARGET_MOUNTPOINT
      ERR=$?
    fi
  fi
}

# do some things after the backup
# this happens regardless of previous errors
doAfter() {
  echo "=============================="
  echo "executing 'after' actions..."
  if [ ! -z "$DUP_BACKUPTARGET_MOUNTPOINT" ]; then
    echo "- unmounting "$DUP_BACKUPTARGET_MOUNTPOINT
    umount $DUP_BACKUPTARGET_MOUNTPOINT
    ERR=$?
  fi
}

doBackup() {
  if [ $ERR -eq 0 ]; then
    echo "=============================="
    echo "starting backup.."
    $DUP_BIN --full-if-older-than $DUP_BACKUP_FORCE_FULL_AFTER --progress \
      --encrypt-key $DUP_KEY \
      --include-filelist $DUP_BACKUPGROUP_INCLUDES \
      $DUP_SOURCE_BASE $DUP_BACKUPTARGET_BASEDIR
    ERR=$?
  fi
  
  if [ $ERR -eq 0 ]; then
    echo "------------------------------"
    echo "starting verification..."
    $DUP_BIN verify \
      --encrypt-key $DUP_KEY \
      --include-filelist $DUP_BACKUPGROUP_INCLUDES \
      $DUP_BACKUPTARGET_BASEDIR $DUP_SOURCE_BASE
    ERR=$?
  fi
  
  if [ $ERR -eq 0 ]; then
    echo "------------------------------"
    echo "pruning..."
    $DUP_BIN remove-all-but-n-full $DUP_BACKUP_PRUNE_EXEMPT_COUNT --force \
      --encrypt-key $DUP_KEY \
      $DUP_BACKUPTARGET_BASEDIR
    ERR=$?
  fi
}

display_usage() {
  SELF=`basename $1`
  echo "Usage: $SELF [options]"
  echo 
  echo "Available options:"
  echo "  -e  --env-file      path to file with environment variables to be source'd"
  echo "  -d  --destination   valid duplicity remote path to use as backup target"
  echo "  -i  --include-file  duplicity include/exclude file"
  echo "  -m  --mountpoint    file path to mount/unmount before/after the backup"
  exit 1
}


# parse input parameters
zparseopts -D -F -K --                      \
  {e,-env-file}:=env_file                   \
  {d,-destination}:=target_basedir          \
  {i,-include-file}:=include_file           \
  {m,-mountpoint}:=target_mountpoint        \
  || return

DUP_BACKUPTARGET_BASEDIR=${target_basedir[-1]}
DUP_BACKUPTARGET_MOUNTPOINT=${target_mountpoint[-1]}
DUP_ENV_FILE=${env_file[-1]}
DUP_BACKUPGROUP_INCLUDES=${include_file[-1]}
BACKUPGROUP=${backup_group[-1]}
BACKUPTARGET=${backup_target[-1]}

# main code
if [[ -z "$DUP_BACKUPTARGET_BASEDIR" 
   || -z "$DUP_BACKUPGROUP_INCLUDES" ]]; then
  display_usage $0
  exit 1
fi

queryGPGInfo

echo "=============================="
echo "gpg key id  : "$DUP_KEY
echo "mount path  : "$DUP_BACKUPTARGET_MOUNTPOINT
echo "destination : "$DUP_BACKUPTARGET_BASEDIR
echo "include file: "$DUP_BACKUPGROUP_INCLUDES
echo "------------------------------"
if read -q "START?start backup? [y/N]: "; then
  echo
  doBefore
  doBackup
  doAfter
else
  echo
  echo "aborting"
fi

