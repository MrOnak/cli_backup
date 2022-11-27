#!/usr/bin/env zsh

# This is an example script you can use to wrap a backup and/or cloudify call
# for use within a cron job.
#
# It'll take care of redirecting STDOUT and STDERR to a temporary logfile.
# It'll send the logfile via email after the job is done
# It'll append the logfile of the run to a permanent logfile and delete the temporary one.
# 
# does need some editing to make it suit your needs, NOT EVERYTHING IS A VARIABLE
# TAKE CARE TO REPLACE ALL /path/to's IN THE backup.zsh CALL ITSELF

TIME_START=$(date +%s)

LOGDIR=/var/log
TMPLOG=$LOGDIR/clibackup-$(date -d @${TIME_START} +%Y%m%d-%H%M%S).log
LOG=$LOGDIR/clibackup.log
MAIL_SUBJECT="backup of $HOST completed"
MAIL_RECEIVER="$USER"

# create log header
echo > $TMPLOG
echo "====================" >> $TMPLOG
echo "starting new backup: "$(date -d @${TIME_START}) >> $TMPLOG
echo >> $TMPLOG

# do create the backup
/path/to/backup.zsh \
	-y \
	-s /path/to/sources \
	-d file:///path/to/destination/ \
	-x /path/to/backup.excludes.txt \
	-e /path/to/env.parameters.sh \
	>> $TMPLOG 2>&1

# create log footer
TIME_END=$(date +%s)
TIME_ELAPSED=$(( $TIME_END - $TIME_START ))

echo >> $TMPLOG
echo "backup complete after: $(date -u -d @${TIME_ELAPSED} +%T) "
echo "====================" >> $TMPLOG
echo >> $TMPLOG

# send logfile via mail
cat $TMPLOG | mail -s $MAIL_SUBJECT $MAIL_RECEIVER

# append logfile to overall log and delete temporary one
cat $TMPLOG >> $LOG
rm $TMPLOG

