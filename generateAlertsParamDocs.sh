#!/bin/bash

# Script should ask for market input
# Check the alerts doc isn't already generated $(ls /data01/cmss/data/alerts/doc/)
# Report whether param docs exist or not 
# Check that the marketconfig is installed $(rpm -qa | grep marketconfig | grep ${market})
# Report whether marketconfig installed or not (If not add server to correct alerts_${market} group in CFengine)
# Check whether the parameters are installed 
# Check if sub directory is owned by rawsync, if yes, ask to change to favsync recursively
# Run alertcoderetriever to get the most updated alert-houses.csv, broker.cfg, and houses.xml
# Check logs to make sure there's no error, else report
# Run alertdocretriever to generate the alerts param documents
# Check logs to make sure there's no error, else report
# Check alerts param docs exists
# If it was a staging sub directory, revert owner from favsync back to rawsync
#
##################################################################################################

set -eu

### Variables ###

MARKET="$@"
BROKER=$(cut -d- -f1 /etc/cmssname)
LIST_PARAM_DOC=$(ls /data01/cmss/data/alerts/doc/${BROKER}_${MARKET}_*/*.pdf 2>/dev/null)
YEAR=$(date +%Y)
MONTH=$(date +%m)
TODAY=$(date +%Y%m%d)


### Functions ###

finish() {

# Failsafe if script exits suddenly in the middle of execution

if [[ $RSYNC = 0 && ! $(stat -c %U ${SMARTSDIR}/${BROKET}) = "rawsync" ]]; then
	echo "Changing ${BROKET} directory permission back to rawsync..."
	sudo chown -R favsync ${BROKET}
fi
}

trap finish EXIT


### Colourise text ###

txtbld=$(tput bold)                     # Bold
bldred=${txtbld}$(tput setaf 1)         # Red
bldgrn=${txtbld}$(tput setaf 120)       # Green
bldyel=${txtbld}$(tput setaf 3)         # Yellow
bldblu=${txtbld}$(tput setaf 33)        # Blue
bldwht=${txtbld}$(tput setaf 7)         # White
txtrst=$(tput sgr0)                     # Reset
info=${bldwht}*${txtrst}                # Feedback
PASS="[ ${bldgrn}PASS${txtrst} ]"
FAILED="[ ${bldred}FAILED${txtrst} ]"
warn=${bldred}*${txtrst}
ques=${bldblu}?${txtrst}


### Check ${MARKET} has been defined else exit

if [[ -z "$@" ]]; then
        echo "You must enter a market and the suffix."
        echo "ie: $0 asx bse_m hkex_s"
        echo "Exiting."
        exit 99
fi


### Start the process
for MARKET in "$@"; do

BROKET=${BROKER}_${MARKET}
GMARKET=$(cut -d- -f1 ${MARKET})

	# Check param doc doesn't exist already, else continue

	if [[ ${LIST_PARAM_DOC} ]]; then
		echo "${BROKET} alert param doc exists... ${PASS}"
		continue
	else
		echo "${MARKET} alert param doc does not exist... ${FAILED}"
	fi

	# Continue routine check if param doc does not exist
	echo "- Checking to see if the prerequisite files and packages are installed..."
	echo "========================================================================="

	# Check alerts package is installed:
	echo -n "- Check: alerts package for ${GMARKET} is installed... "
	if [[ $(rpm -qa | grep -w smarts-alerts-${GMARKET}) ]]; then
		echo "${PASS}"
	else
		echo "${FAILED}"
		echo "   + Please add server to alerts_${MARKET} in cf.groups..."
	fi

	# Check parameters are installed:
		echo -n "Check: parameters files exists... "
	if  [ ! -d /smarts/config/${GMARKET}/dist/parameters ]; then
		echo "${FAILED}"
		echo "   + parameters dir does not exist: /smarts/config/${GMARKET}/dist/parameters/"

	elif [ ! find /smarts/config/${GMARKET}/dist/parameters/ | grep -qi ${GMARKET} ]; then
		echo "${FAILED}"
		echo "   + parameters files for ${GMARKET} does not exist, seek a BA."
	else
		echo "${PASS}"
	fi
 



	# Check $BROKET is owned by favsync, else change to favsync
	elif [[ $(stat -c %U ${SMARTSDIR}/${BROKET}) = "rawsync" ]]; then
		RAWSYNC=0
		echo "- ${BROKET} is owned by rawsync... ${FAILED}"
		echo "- Would you like to change ${BROKET} to the favsync owner? (y/n)"
		read CHANGEPERM

		if [[ ${CHANGEPERM} =y ]]; then
			sudo chown -R favsync ${BROKET}
			if [[ $(stat -c %U ${SMARTSDIR}/${BROKET}) = "favsync" ]]; then
				continue
			else
				echo "- Couldn't change owner permission on ${BROKET}... ${FAILED}"
				echo "- Exiting..."
				exit 5
			fi
		fi
	fi
		
		# Run alertcoderetriever to generate alert-houses.csv, broker.cfg, houses.xml
		echo "- Executing alertcoderetriever..."
		sudo -u favsync /usr/local/alertcoderetriever/bin/alertcoderetriever /data01/cmss/conf/cmss-naming.properties
		tac /var/log/alertcoderetriever/${YEAR}/${MONTH}/${DATE}.log | \
		grep -m1 "${MARKET}: ${TODAY}: Processing market..." -B5 | \
		grep ${MARKET} | tac
	fi
	
done

# if [[ ! $(perl /usr/local/cmss/bin/cmssStatus.pl | grep ${GMARKET}) ]]; then

























