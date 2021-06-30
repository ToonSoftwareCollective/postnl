#!/bin/sh

# Change USER SETTINGS below if needed

#If using proxy uncomment next line and change ipaddress and port
#PROXY="--proxy 192.168.1.2:8888"

# end USER SETTINGS

# "==================================================================================================================================================================="
# "This script can be used to get a json with Track & Trace of packages of Postnl."
# "You need a postnl account to use this script"
#
# "Version: 1.2  - glsf91 - 1-5-2020"
#
# "DON'T RUN this script to many times in a hour. Use at our own risk."
# "==================================================================================================================================================================="
# ""

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
		echo "`date '+%Y-%m-%d %H:%M:%S'`" > $TMPDIR/lastupdate.log
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
#			echo "Set username: $OPTARG"
			USERNAME=$OPTARG
			;;
		p)
#			echo "Set password: $OPTARG"
			PASSWORD=$OPTARG
			;;
		d)
#			echo "Set directory for temporary files: $OPTARG"
			TMPDIR=$OPTARG
			;;
		f)
#			echo "Set force login"
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
	if [ -n "$(find $ACCESSCODEFILE  -mmin -60 -type f)" ]
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

STATUSCODE=`curl $PROXY -w "\n%{http_code}" -o $RESPFILE -k -s -b non-existing -c $COOKIEFILE https://jouw.postnl.nl/identity/Account/Login?ReturnUrl=%2Fidentity%2Fconnect%2Fauthorize%2Fcallback%3Fclient_id%3Dpnl-postnl-site%26audience%3Dpoa-profiles-api%26scope%3Dopenid%2520profile%2520email%2520poa-profiles-api%2520hashed-data%26response_type%3Dcode%26code_challenge_method%3DS256%26code_challenge%3DyngZ35grnSHb1e6tYRpjGOQsnAgkNQ-_QFlW-HE_cEE%26prompt%3Dprompt%26state%3D9840598ffe7dc959516f6bd29458c3ab2b9463266c88cbe367bb1e4ac5387e2d%26redirect_uri%3Dhttps%253A%252F%252Fwww.postnl.nl%252Fsignin%26ui_locales%3Dnl_NL`
if [ ! $STATUSCODE = "200" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from Account/Login step 1 request. See $RESPFILE. Aborting."
	exit 1
fi

REQUESTVERIFICATIONTOKEN=`cat $RESPFILE | tr '\n' '\r' | sed "s/.*__RequestVerificationToken.* value=\"\([^\"]*\).*/\1/"`
if [ ${#REQUESTVERIFICATIONTOKEN} -lt 100 ] || [ ${#REQUESTVERIFICATIONTOKEN} -gt 200 ]
then
	echo "Error: RequestVerificationToken has wrong size. Aborting."
	exit 1
fi

# echo "RequestVerificationToken: $REQUESTVERIFICATIONTOKEN"

URLWITHSTATIC=`cat $RESPFILE | tr '\n' '\r' | sed "s/.*src=\"\([^\"]*\).*/\1/"`
if [ ${#URLWITHSTATIC} -lt 35 ]
then
	echo "Error: UrlWithStatic has wrong size. Aborting."
	exit 1
fi

echo "UrlWithStatic: $URLWITHSTATIC"


# Step 2

RESPFILE="$TMPDIR/postnl-resp2.tmp"
removeFile $RESPFILE

RANDOMSENSORDATA=`dd bs=11 count=1 status=none </dev/urandom | hexdump -e '11/1 "%02x""\n"'`

STATUSCODE=`curl $PROXY -w "\n%{http_code}" -o $RESPFILE -k -s -b $COOKIEFILE -c $COOKIEFILE --request POST --header 'Expect:' --header 'Content-Type: text/plain' --data-raw '{"sensor_data":"'$RANDOMSENSORDATA'1.66-1,2,-94,-100,Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.163 Safari/537.36,uaend,12147,20030107,en-US,Gecko,3,0,0,0,390320,2639919,1920,1160,1920,1200,1778,965,1794,,cpen:0,i1:0,dm:0,cwen:0,non:1,opc:0,fc:0,sc:0,wrc:1,isc:0,vib:1,bat:1,x11:0,x12:1,8334,0.517452032258,793181319959.5,loc:-1,2,-94,-101,do_en,dm_en,t_en-1,2,-94,-105,0,-1,0,0,864,832,0;1,0,0,0,883,851,0;-1,2,-94,-102,0,-1,0,0,864,832,0;1,0,0,0,883,851,0;-1,2,-94,-108,-1,2,-94,-110,-1,2,-94,-117,-1,2,-94,-111,-1,2,-94,-109,-1,2,-94,-114,-1,2,-94,-103,-1,2,-94,-112,https://jouw.postnl.nl/identity/Account/Login-1,2,-94,-115,1,32,32,0,0,0,0,1,0,1586362639919,-999999,16970,0,0,2828,0,0,3,0,0,B5B13FCDF4CA36C7D95DCC2A23DE191A~-1~YAAQDk5lX22iFDpxAQAApeOUWgO7v0AjsdlFKoX+6HQsg8w34qbHV5uqhWQDQ+mBZtaqUOQ0dH9nvZCDqxUeua/VxcrKJV6UEnpiVKtc/toBhuGBK5H95xDMtfB4HxcBesbqctyj1TsB5Kdg7muJ3P7sWOR/49n4c5O3gO74zdQWhHPGQpPI81z7vynNzrsagRpaH+6eojAeufTm/uzqGq7QZR/eoXe/iN6yPmCR9s6u+3twyemZty27C4vuyhbAdDvQDoe65qof6ADb2APRVSqEMUnn3tiT/kFHgKR39U2QFZQN1gVJLLU=~-1~-1~-1,29634,-1,-1,30261693-1,2,-94,-106,0,0-1,2,-94,-119,-1-1,2,-94,-122,0,0,0,0,1,0,0-1,2,-94,-123,-1,2,-94,-124,-1,2,-94,-126,-1,2,-94,-127,-1,2,-94,-70,-1-1,2,-94,-80,94-1,2,-94,-116,2639947-1,2,-94,-118,79837-1,2,-94,-121,;4;-1;0"}'  https://jouw.postnl.nl$URLWITHSTATIC`
if [ ! $STATUSCODE = "201" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from static step 2 request. See $RESPFILE. Aborting."
	exit 1
fi

if ! cat $RESPFILE | tr -d '[[:space:]]' | grep -q "{\"success\":true}"
then
	echo "Error: No success: true received from static request. See $RESPFILE. Aborting."
	exit 1
fi


# Step 3

RESPFILE="$TMPDIR/postnl-resp3.tmp"
removeFile $RESPFILE

STATUSCODE=`curl $PROXY -i -w "\n%{http_code}" -o $RESPFILE -k -s -b $COOKIEFILE -c $COOKIEFILE -L -d "ReturnUrl=&Username=$USERNAME&Password=$PASSWORD&button=login&__RequestVerificationToken=$REQUESTVERIFICATIONTOKEN"  https://jouw.postnl.nl/identity/Account/login`
if [ ! $STATUSCODE = "200" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from Account/Login step 3 request. See $RESPFILE. Aborting."
	exit 1
fi

if grep -q "?botdetected=true" $RESPFILE
then
	echo "Error: Request is detetcted as a bot. After a while it will work again. See $RESPFILE. Aborting."
	exit 1
fi

# Generate CodeVerifier, stateValue and codeChallenge

RANDOM=`dd bs=32 count=1 status=none </dev/urandom`
CODEVERIFIER=`echo -n $RANDOM | hexdump -e '32/1 "%02x""\n"'`
# echo "CodeVerifier: $CODEVERIFIER"
TMP1=`echo -n "$CODEVERIFIER" | openssl dgst -sha256 -binary | openssl base64`
CODECHALLENGE=`echo -n $TMP1 | sed -e 's/\+/-/g' -e 's/\//_/g' -e 's/=//g'`
# echo "codeChallenge: $CODECHALLENGE"

STATEVALUE=`dd bs=32 count=1 </dev/urandom status=none | hexdump -e '32/1 "%02x""\n"'`
# echo "stateValue: $STATEVALUE"


# Step 4

RESPFILE="$TMPDIR/postnl-resp4.tmp"
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
# echo "Code: $CODE"


# Step 5

RESPFILE="$TMPDIR/postnl-resp5.tmp"
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
# echo "Access_code: $ACCESSCODE"
echo -n $ACCESSCODE > $ACCESSCODEFILE

# Step 6

readInbox $ACCESSCODEFILE


#Remove response files.
rm $TMPDIR/postnl-resp?.tmp

# Done
