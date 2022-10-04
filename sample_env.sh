# DO NOT EXECUTE THIS FILE!
#
# This file is meant to be given to backup.zsh and cloudify.zsh via 
# the --env-file parameter. It is then source'd and the exported 
# environment variables used by duplicity and rclone.
# 
# If any of the variables are not given, but needed, the scripts will
# prompt you for them. 
# 
# I highly recommend storing this file with 0400 permissions in a 
# secure location on your disk. Feel free to use calls to `pass`
# in backticks instead of storing the passwords directly.

# duplicity uses a GPG key to encrypt the backup archives
# supply the GPG key id and its passphrase here. 
# backup.zsh will prompt for them if they're not given.
DUP_KEY="GPG KEY ID as returned from gpg --list-keys"
PASSPHRASE="passphrase for that GPG key"
# in case the rclone.conf file is encrypted, supply the password here
RCLONE_CONFIG_PASS=""

# we export everything. Since this file is sourced from within
# the backup.zsh file, the exported variables will _only_ be available
# from within that file. They won't be available after the script has
# finished
export DUP_KEY
export PASSPHRASE
export RCLONE_CONFIG_PASS

