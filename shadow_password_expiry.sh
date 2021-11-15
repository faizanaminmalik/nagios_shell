#!/bin/bash
#Usage: Built as per Nagios NCPA guidelines. To be used in NCPA checks
# This script will check /etc/shadow files to fetch user accounts and determine their password expiry
> /tmp/user-status.txt
user_file="/tmp/user-status.txt"
# Pre-requisite:
# need package 'bc' to be installed on the linux host
# Read + Write Access to /tmp directory for nagios user
# Read Access for /etc/shadow for nagios user
#fetch all users that dont have maxdays set to 99999 i.e infinity days to password expiry

# check first if file /etc/shadow is readable. if not then exit as unknown
if [[ -r /etc/shadow ]]
then
cat /etc/shadow | grep  -v '\!\|\*\|99999' | cut -d: -f1,3,5  | sed /:$/d > /tmp/expirelist.txt
totalaccounts=`cat /tmp/expirelist.txt | wc -l`
else
 echo " Unknown - file /etc/shadow not readable"
 exit 1
fi

for((i=1; i<=$totalaccounts; i++ ))
       do
  todaysdaytime="`date +%s`/86400" # Divide today date-time by 86400
    today_date=`expr $todaysdaytime|bc` # Actual date in unix format

  tuserval=`head -n $i /tmp/expirelist.txt | tail -n 1`
    username=`echo $tuserval | cut -f1 -d:`
    last_change_passwd=`echo $tuserval | cut -f2 -d:`

  passwd_expire_value=`echo $tuserval | cut -f3 -d:`
    calc_passwd_expire=$(( $last_change_passwd + $passwd_expire_value ))
    human_passwd_expire=`date --date "Jan 1, 1970 +$calc_passwd_expire days"`

  remaining_days_passwd_expire=`bc <<< $calc_passwd_expire-$today_date`

if [ $remaining_days_passwd_expire -ge 1 ];
 then
  if [ $remaining_days_passwd_expire -le 15 ];
   then
    #echo -e "$username\t\texpiring  on $human_passwd_expire"
    echo -e "$username\t\texpiring  on $human_passwd_expire" >> /tmp/user-status.txt
   #else
    #echo -e "$username\t\tok  on $human_passwd_expire"
    #echo -e "$username\t\tok  on $human_passwd_expire"
  fi
 else
 #echo -e "$username\t\texpired  on $human_passwd_expire"
 echo -e "$username\t\texpired  on $human_passwd_expire" >> /tmp/user-status.txt
fi

done

exp_passwords=`awk '{print $1,$2,"on",$4,$5,$6,$9}' /tmp/user-status.txt | wc -l`
#echo $exp_passwords
crit=0
if [ $exp_passwords -gt $crit ] && [ -w $user_file ]
then
 body=`awk '{print $1,$2,"on",$4,$5,$6,$9","}' /tmp/user-status.txt`
    echo "CRITICAL - Accounts : "$body
	exit 2
elif [ $exp_passwords -eq $crit ] && [ -w $user_file ]
then
    echo "OK - No User Accounts are expiring in 15 Days or less"
	exit 0
else
 echo "Unknown - Check permission issues on files" $user_file
 exit 1
fi
