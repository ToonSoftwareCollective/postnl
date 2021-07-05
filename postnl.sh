#!/bin/sh

#===================================================================================================================================================================
# This script can be used to get a json with Track & Trace of packages of Postnl.
# You need a postnl account to use this script
#
# Version: 1.3  - glsf91 - 4-7-2021"
#
# DON'T RUN this script to many times in a hour. Use at our own risk."
#==================================================================================================================================================================="


# Change USER SETTINGS below if needed

#PROXY="--proxy 192.168.1.97:8888"   #If using proxy uncomment line and change ipaddress and port

# end USER SETTINGS


usage() {
        echo ""
        echo `basename $0`" [OPTION]

        This script can be used to get a json with Track & Trace of packages of Postnl.

        Options:
        -u <username> (mandatory)
        -p <password> (mandatory)
        -d <directory for temporary files> (mandatory)
        -f Force new login (optional)
        -v with debug output (optional)
        -h Display this help text
		
        example:
            -u \"myusername\" -p \"mypassword\" -d \"/tmp/postnl\"
        "
}

debug_output() {
	if $DEBUG
	then 
		echo "$*"; 
	fi
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

	RESPFILE="$TMPDIR/postnl-resp6.tmp"
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
		mv $RESPFILE $INBOXFILE
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
DEBUG=false

PROGARGS="$@"

#get command options
while getopts "u:p:d:fhv" opt $PROGARGS
do
	case $opt in
		u)
			USERNAME=$OPTARG
			;;
		p)
			PASSWORD=$OPTARG
			;;
		d)
			TMPDIR=$OPTARG
			;;
		f)
			FORCELOGIN=true
			;;
		v)
			DEBUG=true
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


debug_output "Set username: $USERNAME"
debug_output "Set password: $PASSWORD"
debug_output "Set directory for temporary files: $TMPDIR"
debug_output "Set debug output: $DEBUG"
debug_output "Set force login:  $FORCELOGIN"


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

debug_output ""
debug_output "Start step 1"

REQUESTVERIFICATIONTOKEN=""
RETURNURL=""

RESPFILE="$TMPDIR/postnl-resp1.tmp"
removeFile $RESPFILE


# Generate CodeVerifier, stateValue and codeChallenge

RANDOM=`dd bs=32 count=1 status=none </dev/urandom`
CODEVERIFIER=`echo -n $RANDOM | hexdump -e '32/1 "%02x""\n"'`
debug_output "CodeVerifier: $CODEVERIFIER"
TMP1=`echo -n "$CODEVERIFIER" | openssl dgst -sha256 -binary | openssl base64`
CODECHALLENGE=`echo -n $TMP1 | sed -e 's/\+/-/g' -e 's/\//_/g' -e 's/=//g'`
debug_output "codeChallenge: $CODECHALLENGE"

STATEVALUE=`dd bs=32 count=1 </dev/urandom status=none | hexdump -e '32/1 "%02x""\n"'`
debug_output "stateValue: $STATEVALUE"

OUTPUTCURL=`curl --tlsv1.2 $PROXY -i -o $RESPFILE -k -b $COOKIEFILE -c $COOKIEFILE -s -L -w %{url_effective} --request GET --header 'Connection: close' "https://jouw.postnl.nl/identity/connect/authorize?client_id=poa-profiles-web&audience=poa-profiles-api&scope=openid%20profile%20email%20poa-profiles-api%20hashed-data&response_type=code&code_challenge_method=S256&code_challenge=$CODECHALLENGE&prompt=prompt&state=$STATEVALUE&redirect_uri=https://jouw.postnl.nl/account/login&ui_locales=nl_NL"`
#debug_output "Output identity/connect/authorize: $OUTPUTCURL"

if ! echo $OUTPUTCURL | grep -q "^https://jouw.postnl.nl"
then
	echo "Error: Wrong redirect received from connect/authorize request. See $RESPFILE. Aborting."
	echo "       Response: $OUTPUTCURL"
	exit 1
fi

REQUESTVERIFICATIONTOKEN=`cat $RESPFILE | tr '\n' '\r' | sed "s/.*__RequestVerificationToken.* value=\"\([^\"]*\).*/\1/"` 
if [ ${#REQUESTVERIFICATIONTOKEN} -lt 100 ] || [ ${#REQUESTVERIFICATIONTOKEN} -gt 200 ]
then 
	echo "Error: RequestVerificationToken has wrong size. Aborting."
	exit 1
fi

debug_output "RequestVerificationToken: $REQUESTVERIFICATIONTOKEN"

URLWITHSTATIC=`cat $RESPFILE | tr '\n' '\r' | sed "s/.*script.type=.*src=\"\([^\"]*\).*/\1/"` 
if [ ${#URLWITHSTATIC} -lt 35 ] || [ ${#URLWITHSTATIC} -gt 90 ]
then 
	echo "Error: UrlWithStatic has wrong size. Aborting."
	exit 1
fi

debug_output "UrlWithStatic: $URLWITHSTATIC"


RETURNURL=`cat $RESPFILE | tr '\n' '\r' | sed "s/.*id=\"ReturnUrl\" name=\"ReturnUrl\" value=\"\([^\"]*\).*/\1/"` 
if [ ${#RETURNURL} -lt 200 ] || [ ${#RETURNURL} -gt 600 ]
then 
	echo "Error: ReturnUrl has wrong size. Aborting."
	exit 1
fi

RETURNURL=`echo "$RETURNURL"| sed 's/\&amp;/\&/g'`

debug_output "ReturnUrl: $RETURNURL"


# Step 2
debug_output ""
debug_output "Start step 2"

RESPFILE="$TMPDIR/postnl-resp2.tmp"
removeFile $RESPFILE

RANDOMSENSORDATA=`dd bs=11 count=1 status=none </dev/urandom | hexdump -e '11/1 "%02x""\n"'`
debug_output "RANDOMSENSORDATA: $RANDOMSENSORDATA"

STATUSCODE=`curl --tlsv1.2 $PROXY -w "\n%{http_code}" -o $RESPFILE -k -s -b $COOKIEFILE -c $COOKIEFILE --request POST --header 'Expect:' --header 'Connection: close' --header 'Content-Type: text/plain' --data-raw '{"sensor_data":"'$RANDOMSENSORDATA'1.7-1,2,-94,-100,Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36,uaend,12147,20030107,en-US,Gecko,3,0,0,0,399909,5876996,1920,1160,1920,1200,1751,885,1767,,cpen:0,i1:0,dm:0,cwen:0,non:1,opc:0,fc:0,sc:0,wrc:1,isc:0,vib:1,bat:1,x11:0,x12:1,8323,0.19290546196,812667938498,0,loc:-1,2,-94,-101,do_en,dm_en,t_en-1,2,-94,-105,-1,2,-94,-102,-1,2,-94,-108,-1,2,-94,-110,-1,2,-94,-117,-1,2,-94,-111,0,99,-1,-1,-1;-1,2,-94,-109,0,99,-1,-1,-1,-1,-1,-1,-1,-1,-1;-1,2,-94,-114,-1,2,-94,-103,-1,2,-94,-112,https://jouw.postnl.nl/account/en-GB/login-1,2,-94,-115,1,32,32,99,99,0,198,516,0,1625335876996,9,17387,0,0,2897,0,0,517,198,0,ECB30B14F9D32567F2245B547EED3CF7~-1~YAAQB05lX6pbcAN6AQAA206RbQZjqi0USY2vjHf9GR5KyECMd51xAhhIy3vpemr52YzYtIFlsn1yTljV4TYpuD3dvDcjFeaJsK4z/0U0KyccaLCMWfZne8W2Ghezs3aWZJUSdZZJ284ZRNJSyFgEM1kGqk3beh5cn2ibAt4qH/aDnZTMrHUBKI23jGw73WS7FEqPnJNP03mJNDEQhdBe124QdK/I721ZBtgi2wpLr06NWJtH5EMY83fuz4hkWpHZfXFywZwv+cFALAZdD5g2hmWLbmNsx7X+finaD+jAJvfrgwjR2iVIDiz5mahMX8dkorZdN3++N0rBOia4TZKsdLXD4AheAPL/B4shFsB103sRvF3r6LsJoxlAQUhhYCLVJhZ2M4cGCZ9w~-1~||1-BvHxpIrdVU-1-10-1000-2||~-1,37993,760,-395545193,30261693,PiZtE,20316,37,0,-1-1,2,-94,-106,9,2-1,2,-94,-119,20,20,20,20,40,20,0,0,0,0,0,0,20,120,-1,2,-94,-122,0,0,0,0,1,0,0-1,2,-94,-123,-1,2,-94,-124,0.3594e66556ef8,0.db2eef4a7fb0d,0.74a11d3436c6e,0.d38e92cbbc00a,0.90a5d01022534,0.755e18918bb8d,0.0b87885a41aee,0.26f8c6a97a988,0.1e751ac6043ce,0.7ca004bb7aab7;0,0,0,0,0,2,0,5,0,2;0,0,0,2,1,14,2,31,0,8;ECB30B14F9D32567F2245B547EED3CF7,1625335876996,BvHxpIrdVU,ECB30B14F9D32567F2245B547EED3CF71625335876996BvHxpIrdVU,1,1,0.3594e66556ef8,ECB30B14F9D32567F2245B547EED3CF71625335876996BvHxpIrdVU10.3594e66556ef8,180,209,77,110,220,153,52,51,72,117,167,127,60,109,224,158,212,154,204,219,200,130,21,163,249,213,88,150,185,133,79,72,205,0,1625335877266;-1,2,-94,-126,-1,2,-94,-127,11321144241322243122-1,2,-94,-70,-739578230;-1395479418;dis;,7,8;true;true;true;-120;true;24;24;true;false;-1-1,2,-94,-80,5636-1,2,-94,-116,17630982-1,2,-94,-118,123173-1,2,-94,-129,ef9216fc326496a8227a7fc12bd42b7add55e95003515406b71315a7378f5030,1,59e04af447a7870fd61e1342399b41011fd7568b0419030175f3efbee83ca251,Google Inc. (NVIDIA),ANGLE (NVIDIA, NVIDIA GeForce GTX 1650 SUPER Direct3D11 vs_5_0 ps_5_0, D3D11-27.21.14.5671),95f5b71fe531f867faa814bdd4050dd8057206d53ecec1163523560525884870,33-1,2,-94,-121,;3;4;0"}'  https://jouw.postnl.nl$URLWITHSTATIC`
if [ ! $STATUSCODE = "201" ]
then
	echo "Error: Wrong responsecode $STATUSCODE received from static step 2 request. See $RESPFILE. Aborting."
	exit 1
fi

if ! grep -q "{\"success\": true}" $RESPFILE
then
	echo "Error: No success: true received from static request. See $RESPFILE. Aborting."
	exit 1
fi


# Step 3
debug_output ""
debug_output "Start step 3"

RESPFILE="$TMPDIR/postnl-resp3.tmp"
removeFile $RESPFILE

STATUSCODE=`curl --tlsv1.2 $PROXY -i -w "\n%{http_code}" -o $RESPFILE -k -s -b $COOKIEFILE -c $COOKIEFILE -L --header 'Connection: close' --data-urlencode "Username=$USERNAME" --data-urlencode "Password=$PASSWORD" --data-urlencode "ReturnUrl=$RETURNURL" --data-urlencode "__RequestVerificationToken=$REQUESTVERIFICATIONTOKEN" --data-urlencode 'button=login' https://jouw.postnl.nl/identity/Account/login`

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
debug_output "CodeVerifier: $CODEVERIFIER"
TMP1=`echo -n "$CODEVERIFIER" | openssl dgst -sha256 -binary | openssl base64`
CODECHALLENGE=`echo -n $TMP1 | sed -e 's/\+/-/g' -e 's/\//_/g' -e 's/=//g'`
debug_output "codeChallenge: $CODECHALLENGE"

STATEVALUE=`dd bs=32 count=1 </dev/urandom status=none | hexdump -e '32/1 "%02x""\n"'`
debug_output "stateValue: $STATEVALUE"


# Step 4
debug_output ""
debug_output "Start step 4"

RESPFILE="$TMPDIR/postnl-resp4.tmp"
removeFile $RESPFILE

OUTPUTCURL=`curl --tlsv1.2 $PROXY -i -o $RESPFILE -k -b $COOKIEFILE -c $COOKIEFILE -s -L -w %{url_effective} --header 'Connection: close' --request GET "https://jouw.postnl.nl/identity/connect/authorize?client_id=pwb-web&audience=poa-profiles-api&scope=openid%20profile%20email%20poa-profiles-api%20pwb-web-api&response_type=code&code_challenge_method=S256&code_challenge=$CODECHALLENGE&prompt=none&state=$STATEVALUE&redirect_uri=https://jouw.postnl.nl/silent-renew.html&ui_locales=nl_NL"`
#debug_output "Output identity/connect/authorize: $OUTPUTCURL"

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
debug_output "Code: $CODE"


# Step 5
debug_output ""
debug_output "Start step 5"

RESPFILE="$TMPDIR/postnl-resp5.tmp"
removeFile $RESPFILE

STATUSCODE=`curl --tlsv1.2 $PROXY -w "\n%{http_code}" -k -o $RESPFILE -b $COOKIEFILE -c $COOKIEFILE -s -d "grant_type=authorization_code&client_id=pwb-web&code=$CODE&code_verifier=$CODEVERIFIER&redirect_uri=https%3A%2F%2Fjouw.postnl.nl%2Fsilent-renew.html"  https://jouw.postnl.nl/identity/connect/token`
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
debug_output "Access_code: $ACCESSCODE"
echo -n $ACCESSCODE > $ACCESSCODEFILE

# Step 6
debug_output ""
debug_output "Start step 6"

readInbox $ACCESSCODEFILE


#Remove response files.
if ! $DEBUG
then
	rm $TMPDIR/postnl-resp?.tmp
fi

# Done





