# cli_backup

Wrapper scripts for duplicity and rclone.

## context

I'm backing up all my local systems to a central storage location within my LAN. From that central local storage I distribute the backups to various cloud storages for redundancy and resilience in case of natural desasters.

These scripts allow me to gain some flexibility and keep my cron scripts short since they take care of before/after actions and give me a framework to run everything non-interactively.

### backup.zsh

The `backup.zsh` script is responsible to create a backup of "local" content.

- it can mount/unmount a drive just before/after the backup operation.
- it will backup the root directory `/`, so you *must* provide it with an `--include-file` to include/exclude what you need to actually backup. See the provided `sample_home.includes.txt` and `sample_system.includes.txt` for more. This file is passed to `duplicity --include-filelist` so you do want to read up on that, too.
- it will prompt for a GPG key id & its passphrase to use for backup encryption.
- alternatively, you can provide an `--env-file` which is a shellscript that contains your GPG key id and passphrase. This file will be `source`'d, your passphrases will never enter the shell history. See the `sample_env.sh` for what this can look like.
- after backing up the content, `backup.zsh` will verify the backup and prune old ones. A new full backup is  performed monthly, and two full backups (and their increments) are stored before being pruned. You can change this in the variables in the header section of `backup.zsh`

Generally it is assumed that `backup.zsh` is backing up your files to a *local* destination so the destination path would begin with `file://`. But there is nothing stopping you from providing any remote that duplicity understands, including `sftp://`, `rclone://` or `webdav://`. See the `duplicity` manual on how to configure these.

So, in essence you can use `backup.zsh` directly to create a backup in a cloud. If you're doing backups to a single location, this is perfectly fine.

### Usage

It goes without saying that both `backup.zsh` and `cloudify.zsh` need to be executed by a user that has appropriate permissions to the content that is supposed to be backed up / synced.

#### minimal backup

The simplest way to create a backup is this:

`backup.zsh --include-file path/to/include.txt --destination file:///data/backup`

This will create a backup of the root directory `/`, filtered by the `include.txt` and will write the backup files to `/data/backup`. It is assumed that `/data/backup` is a directory that exists and that is writable by the current user. Note that in order to back up to an absolute path on the local file system, you need to give the prefix `file:///some/path` with three slashes: Two for the protocol, the third to make the path absolute.

Before the backup begins `backup.zsh` will query you for the ID of your GPG key and the passphrase to use.

If we assume we only want to backup our `~/Documents` folder, `include.txt` would look like this:

```
/home/USERNAME/Documents/**
- **
```

The first line `/home/USERNAME/Documents/**` explicitly allows the `Documents` folder and everything in it. The second line `- **` *excludes* everything, including the root folder (note the leading `-` in that line). In effect, only the `Documents` folder is backed up.

**Warning:** Make sure you always exclude your backup destination implicitly or explicitly.

#### backup to a temporary mount

If your backup target is a USB-connected drive, you can supply the mount path to `backup.zsh` and the script will automatically mount the drive before the backup, and unmount it after:

`backup.zsh --mountpoint /media/backup --include-file path/to/include.txt --destination file:///media/backup/USERNAME/mybackup`

Note that `--mountpoint` takes the mounted file path, not the `/dev/sdXX` device name. So you need a matching entry in `/etc/fstab` or similar.

#### the env file

If you do not want to enter your GPG key id and passphrase manually you can provide the script with two environment variables:

* `DUP_KEY` contains the GPG key id 
* `PASSPHRASE` contains the GPG passphrase

`DUP_KEY` is a variable that is used by `backup.zsh` directly, `PASSPHRASE` is defined by `duplicity`.

It ultimately doesn't matter how you provide these environment variables and several ways are suggested in the `duplicity` man file. It is worth your time reading about this, to find a solution that works securely in your context.

`backup.zsh` and `cloudify.zsh` both provide an `--env-file` option which takes a path to a shell script containing these variables. The scripts will `source` that file and make the variables in it available that way. See the provided `sample_env.sh` file for details.

`backup.zsh --include-file path/to/include.txt --destination file:///data/backup --env-file path/to/env_file.sh`

The env file can also be used in case your `rclone` config file is encrypted, simply include a `RCLONE_CONFIG_PASS` variable.

It is important that you understand that the env file will likely contain the keys to your backup kingdom. Keep it safe and if you cannot do this in your environment, find a different solution to provide the passphrases.

## cloudify.zsh

I'm in the situation where I want to create copies of (some) of my backups to more than one cloud provider, for redundancy. 

While technically feasible to do this directly through `backup.zsh`, it isn't efficient: Making a backup from sources requires more computational power than duplicating an existing backup. Additionally, if the source system changes between backups to cloud a and b, both backups will be intact, but they will be different from each other. That is less than helpful and can lead to confusion and mistakes.

Enter the `cloudify.zsh` script. It will do an `rclone sync` of a local directory to a valid `rclone` remote. I use this to sync my local backup folder(s) with one cloud at a time. As a result all cloud copies are identical and the operation is less CPU intensive than creating a fresh backup everytime.

Note: rclone can sync from local to remote or between two remotes. `cloudify --source` therefore does allow urls or local paths. 

### the env file for cloudify

It is perfectly feasible to use the same env file for both `backup.zsh` and `cloudify.zsh` but you may not want to: `cloudify` itself takes no environment parameters, the only ones relevant are what you need for `rclone`, for example `RCLONE_CONFIG_PASS` in case your `rclone.conf` is encrypted. You probably want to leave your GPG encryption key id and passphrase out of the env file for `cloudify`.

### Usage

Calling `cloudify.zsh` shares many commonalities with `backup.zsh`. The parameters `--mountpoint`, `--destination` and `--env-file` have the same meaning as described above.

But `cloudify.zsh` requires a `--source` parameter which isn't present for `backup.zsh`. Through `--source` you provide the script with the base folder to sync. It can either be a file path on the local file system (absolute or relative) or can be a valid `rclone` remote. So in essence `cloudify.zsh` can be used to sync a local folder into the cloud, sync two remotes, or sync one remote back to local.

#### syncing local to remote

```
cloudify.zsh --source /data/backup --destination scp://user@host:path/to/backup
```

#### syncing between two remotes

```
cloudify.zsh --source scp://user@host:path/to/backup --destination gdrive:backups
```

#### syncing from remote to local

```
cloudify.zsh --source scp://user@host:path/to/backup --destination file:///data/backup
```

## a realistic scenario

Assume a small LAN with several computers that need backup. The LAN contains a NAS `nas.local` which will act as LAN-local backup target. Two cloud storage services exist: An amazon S3 bucket configured as `s3` and one storage box accessible via `scp` and configured in `rclone` as `storagebox`

1. On all local machines we set up a cronjob to run `backup.zsh -y -i includes.txt -e envfile.sh -d scp://user@nas.local:backups/$HOST`. This will backup the files defined in `includes.txt` on each machine to `nas.local` into a folder that matches the source machines' hostname.
2. On the NAS we set up a cronjob to sync the backup folder with both clouds. In essence the cronjob will run 
    * `cloudify.zsh -e envfile.sh -s backups -d s3:bucket/backup` and
    * `cloudify.zsh -e envfile.sh -s backups -d storagebox:backups`

## On restoring the backup

I wrote this set of scripts to *create* and *distribute* my backups while providing some convenience functionality. The scripts are not intended as, and probably will never become, a complete backup/restore solution. 

`duplicity`, which is the used core for backups is perfectly capable to list backup contents and restore full or partial backups from anywhere in reach of `rclone`. 

Refer to the man pages of these to for more.

## prerequisites

I'm using `zsh` so these scripts rely on some features of that shell. Note that you do not need to have `zsh` as your active shell, it being available should suffice.

These scripts are merely wrappers for [rclone](https://rclone.org/) and [duplicity](https://duplicity.gitlab.io/), so you need those installed, and in case of `rclone`, configured.

I'm running `duplicity` version 1.0.0 and `rclone` version 1.59.2, these are known to work but I doubt that earlier versions will not work. 

**Do invest time in understanding how both applications work and how you create safe backups with them.** It is likely that you'll find that you need `gpg` and at least one key, and maybe `pass` as well to keep your passphrases out of the shell history and out of logfiles.

## disclaimer

Please don't ask me about general usage of `duplicity` or `rclone`. Both files come with extensive manuals and an active community, you will find more robust information there than with me.

You are responsible for the security and integrity of your own backups. I can not and will not be held responsible for any issues including loss of data, caused by these scripts. They are provided as-is in the hope that they are useful.
