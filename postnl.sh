#!/bin/sh

# Change USER SETTINGS below if needed

#If using proxy uncomment next line and change ipaddress and port
#PROXY="--proxy 192.168.1.2:8888"

# end USER SETTINGS

echo "==================================================================================================================================================================="
echo "This script can be used to get a json with Track & Trace of packages of Postnl."
echo "You need a postnl account to use this script"
echo ""
echo "Version: 1.0  - glsf91 - 28-2-2020"
echo ""
echo "DON'T RUN this script to many times in a hour. Use at our own risk."
echo "==================================================================================================================================================================="
echo ""

usage() {
        echo ""
        echo `basename $0`" [OPTION]

        This script can be used to get a json with Track & Trace of packages of Postnl.

        Options:
        -u <username> (mandatory)
        -p <password> (mandatory)
        -d <directory for temporary files> (mandatory)
		-f Force new login (optional)
        -h Display this help text
		
        example:
            -u \"myusername\" -p \"mypassword\" -d \"/tmp/postnl\"
        "
}

exit_abnormal() {                              # Function: Exit with error.
  usage
  exit 1
}

removeFile() {
	if [ -f "$1" ]
	then
		rm $1
	fi
}

readInbox() {
	if [ ! -s "$1" ]
	then
		echo "Error readInbox(): file $1 with accesscode doesn't exist. Abort"
		return 1
	fi

	ACCODE=`cat $1`

	RESPFILE="$TMPDIR/postnl-resp5.tmp"
	removeFile $RESPFILE

	STATUSCODE=`curl $PROXY -w "\n%{http_code}" -k -o $RESPFILE -b $COOKIEFILE -c $COOKIEFILE -s -H "Authorization: Bearer $ACCODE" "https://jouw.postnl.nl/web/api/default/inbox"`
	if [ ! $STATUSCODE = "200" ]
	then
		echo "Error: Wrong responsecode $STATUSCODE received from default/inbox request. See $RESPFILE. Aborting."
		if [ $STATUSCODE = "401" ]
		then
			removeFile $1   # remove access code file
			echo "Access code file removed for next run"
		fi
		return 1
	fi

	if [ -s $RESPFILE ]
	then
		cp $RESPFILE $INBOXFILE
		echo "Succeeded: inbox json received from postnl"
	else
		echo "Warning: succeeded but empty json received for inbox request."
		echo "Previous json file will not be replaced."
	fi
}

#Start

USERNAME=""
PASSWORD=""
TMPDIR=""
FORCELOGIN=false

PROGARGS="$@"

#get command options
while getopts "u:p:d:fh" opt $PROGARGS
do
	case $opt in
		u)
			echo "Set username: $OPTARG"
			USERNAME=$OPTARG
			;;
		p)
			echo "Set password: $OPTARG"
			PASSWORD=$OPTARG
			;;
		d)
			echo "Set directory for temporary files: $OPTARG"
			TMPDIR=$OPTARG
			;;
		f)
			echo "Set force login"
			FORCELOGIN=true
			;;
		h)  usage
			exit 1
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit_abnormal
			;;
		:)               # If expected argument omitted:
			echo "Error: -${OPTARG} requires an argument."
			exit_abnormal
			;;
		*)               # If unknown (any other) option:
			exit_abnormal
			;;
	esac
done

# Check 
[ -z "$USERNAME" ] && exit_abnormal
[ -z "$PASSWORD" ] && exit_abnormal
[ -z "$TMPDIR" ] && exit_abnormal

echo ""

COOKIEFILE="$TMPDIR/postnl-cookie-jar.txt"
ACCESSCODEFILE="$TMPDIR/postnl-acccescode"
INBOXFILE="$TMPDIR/POSTNL-Inbox.json"

#check if the directory already exists, otherwise create the directory
if [ ! -d $TMPDIR ]
then
	mkdir -p $TMPDIR
fi

if [ ! -d $TMPDIR ]
then
	echo "Error: Directory $TMPDIR creation failed. Aborting."
    exit 1
fi

cd $TMPDIR

#if accesscode is less then 60 minutes old, reuse it. If older or not exist, start from beginning.
if [ -f $ACCESSCODEFILE ] && ! $FORCELOGIN
then
	if [ `stat -c %Y $ACCESSCODEFILE` -ge $(( `date +%s` - 3500 )) ]
	then 
		echo "Found recent accesscode. Re-use this accesscode."
		readInbox $ACCESSCODEFILE
		exit
	fi
fi

echo "No recent access code. Start login postnl sequence."


removeFile $COOKIEFILE


# Step 1

REQUESTVERIFICATIONTOKEN=""

RESPFILE="$TMPDIR/postnl-resp1.tmp"
removeFile $RESPFILE

STATUSCODE=`curl $PROXY -w "\n%{http_code}" -o $RESPFILE -k -s -b non-existing -c $COOKIEFILE https://jouw.postnl.nl/identity/Account/Login`
if [ ! $STATUSCODE = "200" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from Account/Login 1st request. See $RESPFILE. Aborting."
	exit 1
fi

REQUESTVERIFICATIONTOKEN=`cat $RESPFILE | tr '\n' '\r' | sed "s/.*__RequestVerificationToken.* value=\"\([^\"]*\).*/\1/"` 
if [ ${#REQUESTVERIFICATIONTOKEN} -lt 100 ] || [ ${#REQUESTVERIFICATIONTOKEN} -gt 200 ]
then 
	echo "Error: RequestVerificationToken has wrong size. Aborting."
	exit 1
fi

echo "RequestVerificationToken: $REQUESTVERIFICATIONTOKEN"

# Step 2

RESPFILE="$TMPDIR/postnl-resp2.tmp"
removeFile $RESPFILE

STATUSCODE=`curl $PROXY -w "\n%{http_code}" -o $RESPFILE -k -s -b $COOKIEFILE -c $COOKIEFILE -L -d "ReturnUrl=&Username=$USERNAME&Password=$PASSWORD&button=login&__RequestVerificationToken=$REQUESTVERIFICATIONTOKEN"  https://jouw.postnl.nl/identity/Account/login`
if [ ! $STATUSCODE = "200" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from Account/Login 2nd request. See $RESPFILE. Aborting."
	exit 1
fi

# Generate CodeVerifier, stateValue and codeChallenge

RANDOM=`dd bs=32 count=1 status=none </dev/urandom`
CODEVERIFIER=`echo -n $RANDOM | hexdump -e '32/1 "%02x""\n"'`
echo "CodeVerifier: $CODEVERIFIER"
TMP1=`echo -n "$CODEVERIFIER" | sha256sum | sed 's/\([0-9,a-z]*\).*/\1/' |  perl -pe 's/([0-9a-f]{2})/chr hex $1/gie' |dd bs=32 count=1 status=none | openssl base64`
CODECHALLENGE=`echo -n $TMP1 | sed -e 's/\+/-/g' -e 's/\//_/g' -e 's/=//g'`
echo "codeChallenge: $CODECHALLENGE"

STATEVALUE=`dd bs=32 count=1 </dev/urandom status=none | hexdump -e '32/1 "%02x""\n"'`
echo "stateValue: $STATEVALUE"


# Step 3

RESPFILE="$TMPDIR/postnl-resp3.tmp"
removeFile $RESPFILE

OUTPUTCURL=`curl $PROXY -i -o $RESPFILE -k -b $COOKIEFILE -c $COOKIEFILE -s -L -w %{url_effective} "https://jouw.postnl.nl/identity/connect/authorize?client_id=pwb-web&audience=poa-profiles-api&scope=openid%20profile%20email%20poa-profiles-api%20pwb-web-api&response_type=code&code_challenge_method=S256&code_challenge=$CODECHALLENGE&prompt=none&state=$STATEVALUE&redirect_uri=https://jouw.postnl.nl/silent-renew.html&ui_locales=nl_NL"`
#echo "Output identity/connect/authorize: $OUTPUTCURL"

if ! echo $OUTPUTCURL | grep -q "^https://jouw.postnl.nl"
then
	echo "Error: Wrong redirect received from connect/authorize request. See $RESPFILE. Aborting."
	echo "       Response: $OUTPUTCURL"
	exit 1
fi

if ! echo $OUTPUTCURL | grep -q "code="
then
	echo "Error: Wrong redirect received from connect/authorize request. See $RESPFILE. Aborting."
	echo "       Response: $OUTPUTCURL"
	exit 1
fi

CODE=`echo -n $OUTPUTCURL | sed 's/.*code=\(.*\)\&scope.*/\1/'`
echo "Code: $CODE"


# Step 4

RESPFILE="$TMPDIR/postnl-resp4.tmp"
removeFile $RESPFILE

STATUSCODE=`curl $PROXY -w "\n%{http_code}" -k -o $RESPFILE -b $COOKIEFILE -c $COOKIEFILE -s -d "grant_type=authorization_code&client_id=pwb-web&code=$CODE&code_verifier=$CODEVERIFIER&redirect_uri=https%3A%2F%2Fjouw.postnl.nl%2Fsilent-renew.html"  https://jouw.postnl.nl/identity/connect/token`
if [ ! $STATUSCODE = "200" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from connect/token request. See $RESPFILE. Aborting."
	if grep -q "invalid_grant" $RESPFILE
	then
		echo "Invalid grant received. Try again if you want in a few minutes. Aborting"
	fi
	exit 1
fi
# {"error":"invalid_grant"}
if ! grep -q "access_token" $RESPFILE
then
	echo "Error: No access_code received from connect/token request. See $RESPFILE. Aborting."
	exit 1
fi

ACCESSCODE=`grep -o '"access_token":"[^"]*' $RESPFILE | grep -o '[^"]*$'`
echo "Access_code: $ACCESSCODE"
echo -n $ACCESSCODE > $ACCESSCODEFILE

# Step 5

readInbox $ACCESSCODEFILE


#Remove response files.
#rm $TMPDIR/postnl-resp?.tmp

# Done





