# In the following script I will attempt to sync the kdbx password database between KrEaTor and berhl.
# In order to do so, I will need to set up a cron job for every 2 mins.
# I want the sync agent to only sync in the direction where the change has occured more recently. This means that I should preserve modification times upon file transfer.
local_database="$HOME/Documents/Database.kdbx"
remote_database="Documents/Database.kdbx"
server="k0@berhl.hopto.org"
username="dmiraj"

case $@ in
	'')
		# I should decide wheter to pull or push.
		# I need to compare modification times.
		# I want to set up a systerm service unit, that will setup a file under /etc/cron.d
		# The main purpose of this setup is to only start syncing when my laptop has internet.
		# Once the service unit stops (i.e: its dependencies fail) then the file under /etc/cron.d will be deleted.
		remote_mod_time=$(ssh -p 6897 $server stat $remote_database | awk '/Modify/ { print $2 " " $3 }')
		local_mod_time=$(stat $local_database | awk '/Modify/ { print $2 " " $3 }')
		echo $local_mod_time
		if [[ "$remote_mod_time" < "$local_mod_time" ]]; then
			echo "Updating the remote databse on berhl"
			rsync --times \
				--update \
				--perms \
				--rsh="ssh -p 6897" \
				$local_database $server:$remote_database
			if [ $? = '0' ]; then
				echo "Success !"
			fi

		elif [[ "$local_mod_time" < "$remote_mod_time" ]]; then
			echo "Updating the local database"
			rsync --times \
				--update \
				--perms \
				--rsh="ssh -p 6897" \
				$server:$remote_database $local_database
			if [ $?  = '0']; then
				echo "Success !"
			fi
		else
			echo -e "KreAT0r mod time = berhl mod time.\nNo need to sync."
		fi
		;;

	configure)
		if [ "$(id -u)" != '0' ]; then
			echo "You will need to run in elevated privileges in order to write in /etc/crontab"
		else
			# Verify first if a similar line does not exist, in case this is not the first time it has been setup.
			cronfile=$(cat /etc/crontab)
			cronline="*/5 * * * * $username syncpasswd.sh" # Executes this script every 5 minutes.
			if [[ "$cronfile" =~ "$cronline" ]]; then
				echo "cron line already exist in file"
			else
				echo "Appending the cron command into /etc/crontab"
				echo "$cronline" >> /etc/crontab
			fi
		fi
		# This script needs to start running once my laptop has internet. So in the following I will set up a system unit.
		;;
esac
