#!/bin/sh

#===================================================================================================================================================================
# This script retrieves a json with the Track & Trace of the packages in your Postnl account.
# You need a postnl account to use this script.
#
# Version: 2.0  - 2026-09-06
#   Rewritten for the new PostNL login (Akamai Identity Cloud "Hosted Login" / Janrain Capture) that
#   replaced the old jouw.postnl.nl/identity flow. Packages are now read from the account GraphQL API
#   and the track-and-trace API, and written to POSTNL-Inbox.json in the same layout the app expects.
#
# DON'T RUN this script too many times in an hour. Use at your own risk.
#==================================================================================================================================================================="


# Change USER SETTINGS below if needed

#PROXY="--proxy 192.168.1.97:8888"   #If using proxy uncomment line and change ipaddress and port

# end USER SETTINGS


# ---- Fixed PostNL/Akamai identity constants (the account web app uses these) ----
TENANT="https://login.postnl.nl/101112a0-4a0f-4bbb-8176-2f1b2d370d7c"
OIDC_CLIENT="deb0a372-6d72-4e09-83fe-997beacbd137"
REDIRECT_URI="postnl://login"
REDIRECT_URI_ENC="postnl%3A%2F%2Flogin"
SCOPE="openid profile email poa-profiles-api"
SCOPE_ENC="openid%20profile%20email%20poa-profiles-api"
CAPTURE_SERVER="https://login.postnl.nl"
GRAPHQL_URL="https://jouw.postnl.nl/account/api/graphql"
TT_URL="https://jouw.postnl.nl/track-and-trace/api/trackAndTrace"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

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

exit_abnormal() {
	usage
	exit 1
}

removeFile() {
	if [ -f "$1" ]
	then
		rm "$1"
	fi
}

# Extract a "key":"value" string field from a flat json blob (first match). Prints raw value (may contain json escapes).
jstr() {
	# $1 = json, $2 = key
	printf '%s' "$1" | sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p' | head -n 1
}

# Extract a "key":<value> where value is bool/number/null (first match)
jval() {
	printf '%s' "$1" | sed -n 's/.*"'"$2"'":\([^,}]*\).*/\1/p' | head -n 1
}

# Sanitize a value so it is safe to place inside a json string in our output:
# drop double quotes and backslashes and control chars (values are short display text).
jsan() {
	printf '%s' "$1" | tr -d '"\\' | tr -d '\000-\037' | sed -e 's/^ *//' -e 's/ *$//'
}


#Start

USERNAME=""
PASSWORD=""
TMPDIR=""
FORCELOGIN=false
DEBUG=false

PROGARGS="$@"

while getopts "u:p:d:fhv" opt $PROGARGS
do
	case $opt in
		u) USERNAME=$OPTARG ;;
		p) PASSWORD=$OPTARG ;;
		d) TMPDIR=$OPTARG ;;
		f) FORCELOGIN=true ;;
		v) DEBUG=true ;;
		h) usage; exit 1 ;;
		\?) echo "Invalid option: -$OPTARG"; exit_abnormal ;;
		:) echo "Error: -${OPTARG} requires an argument."; exit_abnormal ;;
		*) exit_abnormal ;;
	esac
done

debug_output "Set username: $USERNAME"
debug_output "Set directory for temporary files: $TMPDIR"
debug_output "Set debug output: $DEBUG"
debug_output "Set force login:  $FORCELOGIN"

[ -z "$USERNAME" ] && exit_abnormal
[ -z "$PASSWORD" ] && exit_abnormal
[ -z "$TMPDIR" ] && exit_abnormal

echo ""

COOKIEFILE="$TMPDIR/postnl-cookie-jar.txt"
REFRESHFILE="$TMPDIR/postnl-refreshtoken"
INBOXFILE="$TMPDIR/POSTNL-Inbox.json"

if [ ! -d "$TMPDIR" ]; then mkdir -p "$TMPDIR"; fi
if [ ! -d "$TMPDIR" ]; then echo "Error: Directory $TMPDIR creation failed. Aborting."; exit 1; fi

cd "$TMPDIR"

ACCESSTOKEN=""

# ---------------------------------------------------------------------------
# refreshTokens: use a stored refresh token to get a fresh access token.
# Sets ACCESSTOKEN on success and rotates the stored refresh token. Returns 1 on failure.
# ---------------------------------------------------------------------------
refreshTokens() {
	if [ ! -s "$REFRESHFILE" ]; then return 1; fi
	RT=`cat "$REFRESHFILE"`
	RESP="$TMPDIR/postnl-refresh.tmp"
	removeFile "$RESP"
	STATUSCODE=`curl $PROXY -s -k -A "$UA" -w "%{http_code}" -o "$RESP" \
		--data-urlencode "grant_type=refresh_token" \
		--data-urlencode "client_id=$OIDC_CLIENT" \
		--data-urlencode "refresh_token=$RT" \
		"$TENANT/login/token"`
	if [ ! "$STATUSCODE" = "200" ]; then
		debug_output "Refresh token rejected (status $STATUSCODE). Full login required."
		return 1
	fi
	ACCESSTOKEN=`jstr "\`cat $RESP\`" access_token`
	NEWRT=`jstr "\`cat $RESP\`" refresh_token`
	if [ -z "$ACCESSTOKEN" ]; then return 1; fi
	if [ -n "$NEWRT" ]; then printf '%s' "$NEWRT" > "$REFRESHFILE"; fi
	echo "Re-used login via refresh token."
	return 0
}

# ---------------------------------------------------------------------------
# fullLogin: complete the hosted-login flow with username/password. Sets ACCESSTOKEN and stores refresh token.
# ---------------------------------------------------------------------------
fullLogin() {
	echo "Start full login sequence."
	removeFile "$COOKIEFILE"

	# PKCE
	CODEVERIFIER=`dd bs=32 count=1 status=none </dev/urandom | hexdump -e '32/1 "%02x""\n"'`
	CODECHALLENGE=`printf '%s' "$CODEVERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr -d '\n' | sed -e 's/+/-/g' -e 's/\//_/g' -e 's/=//g'`
	STATE=`dd bs=16 count=1 status=none </dev/urandom | hexdump -e '16/1 "%02x""\n"'`

	AUTHURL="$TENANT/login/authorize?client_id=$OIDC_CLIENT&response_type=code&scope=$SCOPE_ENC&redirect_uri=$REDIRECT_URI_ENC&state=$STATE&code_challenge=$CODECHALLENGE&code_challenge_method=S256"

	# Step 1: authorize -> redirect to hosted login page
	H1="$TMPDIR/postnl-h1.tmp"; removeFile "$H1"
	curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -D "$H1" -o /dev/null "$AUTHURL"
	AUTHUI=`grep -i '^location:' "$H1" | sed 's/^[Ll]ocation: *//' | tr -d '\r' | head -n 1`
	if ! echo "$AUTHUI" | grep -q "auth-ui"; then
		echo "Error: no hosted-login redirect received from authorize. Aborting."
		return 1
	fi
	AUTHUIQUERY=`echo "$AUTHUI" | sed 's/^[^?]*?//'`

	# Step 2: load hosted login page (sets _csrf_token cookie, exposes capture settings)
	R2="$TMPDIR/postnl-r2.tmp"; removeFile "$R2"
	curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -o "$R2" "$AUTHUI"
	CAP_APPID=`grep -o "appId: *'[^']*'" "$R2" | grep -v "'None'" | head -n 1 | sed "s/.*'\([^']*\)'/\1/"`
	CAP_CLIENT=`grep -o "clientId: *'[^']*'" "$R2" | head -n 1 | sed "s/.*'\([^']*\)'/\1/"`
	CAP_FLOW=`grep -o "flowName: *'[^']*'" "$R2" | head -n 1 | sed "s/.*'\([^']*\)'/\1/"`
	CSRF=`grep "_csrf_token" "$COOKIEFILE" | tail -n 1 | awk '{print $NF}'`
	[ -z "$CAP_FLOW" ] && CAP_FLOW="standard"
	if [ -z "$CAP_APPID" ] || [ -z "$CAP_CLIENT" ]; then
		echo "Error: could not read login widget settings. Aborting."
		return 1
	fi
	debug_output "capture appId=$CAP_APPID client=$CAP_CLIENT flow=$CAP_FLOW"

	# Step 2b: flow file -> current flow version
	FLOWJS="$TMPDIR/postnl-flow.tmp"; removeFile "$FLOWJS"
	curl $PROXY -s -k -A "$UA" -o "$FLOWJS" "https://ssl-static.janraincapture.com/widget_data/flow.js:$CAP_APPID:nl-NL:HEAD:$CAP_FLOW"
	FLOWVERSION=`grep -o '"version": *"[^"]*"' "$FLOWJS" | head -n 1 | sed 's/.*: *"\([^"]*\)"/\1/'`
	[ -z "$FLOWVERSION" ] && FLOWVERSION="HEAD"
	debug_output "flowVersion=$FLOWVERSION"

	# Step 3: submit credentials to the capture widget
	CAPREDIRECT="${AUTHUI}&socialRedirect=True"
	TRANSID=`dd bs=20 count=1 status=none </dev/urandom | hexdump -e '20/1 "%02x""\n"'`
	R3="$TMPDIR/postnl-r3.tmp"; removeFile "$R3"
	curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -o "$R3" \
		-e "$AUTHUI" -H "Origin: https://login.postnl.nl" \
		--data "utf8=%E2%9C%93" \
		--data-urlencode "js_version=d445bf4" \
		--data-urlencode "capture_screen=signIn" \
		--data-urlencode "capture_transactionId=$TRANSID" \
		--data-urlencode "flow=$CAP_FLOW" \
		--data-urlencode "client_id=$CAP_CLIENT" \
		--data-urlencode "redirect_uri=$CAPREDIRECT" \
		--data-urlencode "response_type=token" \
		--data-urlencode "flow_version=$FLOWVERSION" \
		--data-urlencode "settings_version=" \
		--data-urlencode "locale=nl-NL" \
		--data-urlencode "recaptcha_version=2" \
		--data-urlencode "form=signInForm" \
		--data-urlencode "signInEmailAddress=$USERNAME" \
		--data-urlencode "currentPassword=$PASSWORD" \
		"$CAPTURE_SERVER/widget/traditional_signin.jsonp" >/dev/null 2>&1

	# Step 3b: fetch the sign-in result (holds the short-lived capture access token)
	R3B="$TMPDIR/postnl-r3b.tmp"; removeFile "$R3B"
	NOW=`date +%s`000
	curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -o "$R3B" \
		-e "$AUTHUI" "$CAPTURE_SERVER/widget/get_result.jsonp?transactionId=$TRANSID&cache=$NOW"
	if grep -q '"statusMessage":"invalidCredentials"' "$R3B" || grep -q 'invalidPassword' "$R3B"; then
		echo "Error: PostNL rejected the username/password. Aborting."
		return 1
	fi
	CAPTOKEN=`jstr "\`cat $R3B\`" accessToken`
	if [ -z "$CAPTOKEN" ]; then
		echo "Error: no capture access token received (login failed). Aborting."
		return 1
	fi

	# Step 4: hand the capture token to auth-ui token-url, establishing the SSO session cookie
	curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -o /dev/null \
		-e "$AUTHUI" \
		--data-urlencode "authenticated=True" \
		--data-urlencode "registering=False" \
		--data-urlencode "accessToken=$CAPTOKEN" \
		--data-urlencode "_csrf_token=$CSRF" \
		"$TENANT/auth-ui/token-url?$AUTHUIQUERY"

	# Step 4b: re-request authorize; with the SSO cookie it redirects to redirect_uri?code=...
	H4B="$TMPDIR/postnl-h4b.tmp"; removeFile "$H4B"
	curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -D "$H4B" -o /dev/null "$AUTHURL"
	LOC=`grep -i '^location:' "$H4B" | sed 's/^[Ll]ocation: *//' | tr -d '\r' | head -n 1`
	CODE=`echo "$LOC" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p'`
	N=0
	while [ -z "$CODE" ] && echo "$LOC" | grep -q '^https://' && [ $N -lt 6 ]; do
		N=$((N+1))
		HN="$TMPDIR/postnl-h4b_$N.tmp"; removeFile "$HN"
		curl $PROXY -s -k -A "$UA" -c "$COOKIEFILE" -b "$COOKIEFILE" -D "$HN" -o /dev/null "$LOC"
		LOC=`grep -i '^location:' "$HN" | sed 's/^[Ll]ocation: *//' | tr -d '\r' | head -n 1`
		CODE=`echo "$LOC" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p'`
	done
	if [ -z "$CODE" ]; then
		echo "Error: no authorization code received after login. Aborting."
		return 1
	fi

	# Step 5: exchange the code for tokens
	R5="$TMPDIR/postnl-r5.tmp"; removeFile "$R5"
	STATUSCODE=`curl $PROXY -s -k -A "$UA" -w "%{http_code}" -o "$R5" \
		--data-urlencode "grant_type=authorization_code" \
		--data-urlencode "client_id=$OIDC_CLIENT" \
		--data-urlencode "code=$CODE" \
		--data-urlencode "redirect_uri=$REDIRECT_URI" \
		--data-urlencode "code_verifier=$CODEVERIFIER" \
		"$TENANT/login/token"`
	if [ ! "$STATUSCODE" = "200" ]; then
		echo "Error: token exchange failed (status $STATUSCODE). Aborting."
		return 1
	fi
	ACCESSTOKEN=`jstr "\`cat $R5\`" access_token`
	NEWRT=`jstr "\`cat $R5\`" refresh_token`
	if [ -z "$ACCESSTOKEN" ]; then
		echo "Error: no access token received from token endpoint. Aborting."
		return 1
	fi
	if [ -n "$NEWRT" ]; then printf '%s' "$NEWRT" > "$REFRESHFILE"; fi
	echo "Full login succeeded."
	return 0
}

# ---------------------------------------------------------------------------
# getToken: obtain an access token, preferring the cached refresh token.
# ---------------------------------------------------------------------------
getToken() {
	if ! $FORCELOGIN; then
		if refreshTokens; then return 0; fi
	fi
	fullLogin
	return $?
}


getToken || exit 1


# ---------------------------------------------------------------------------
# Fetch the list of tracked shipments (GraphQL)
# ---------------------------------------------------------------------------
GQLQUERY='{"query":"{ trackedShipments { receiverShipments { key creationDateTime title barcode delivered deliveredTimeStamp deliveryWindowFrom deliveryWindowTo shipmentType deliveryAddressType sourceDisplayName } senderShipments { key creationDateTime title barcode delivered deliveredTimeStamp deliveryWindowFrom deliveryWindowTo shipmentType deliveryAddressType sourceDisplayName } } }"}'

SHIPFILE="$TMPDIR/postnl-shipments.tmp"; removeFile "$SHIPFILE"
STATUSCODE=`curl $PROXY -s -k -A "$UA" -w "%{http_code}" -o "$SHIPFILE" \
	-H "Authorization: Bearer $ACCESSTOKEN" -H "Content-Type: application/json" \
	--data "$GQLQUERY" "$GRAPHQL_URL"`
if [ ! "$STATUSCODE" = "200" ]; then
	echo "Error: shipments request failed (status $STATUSCODE). See $SHIPFILE. Aborting."
	# a stale refresh token can cause 401; drop it so the next run does a full login
	if [ "$STATUSCODE" = "401" ]; then removeFile "$REFRESHFILE"; fi
	exit 1
fi
if ! grep -q "trackedShipments" "$SHIPFILE"; then
	echo "Error: unexpected shipments response. See $SHIPFILE. Aborting."
	exit 1
fi


# ---------------------------------------------------------------------------
# Split the GraphQL response into per-shipment json objects and (re)build the inbox json.
# ---------------------------------------------------------------------------

# isolate receiver / sender arrays
RECEIVERPART=`tr -d '\n' < "$SHIPFILE" | sed -n 's/.*"receiverShipments":\[\(.*\)\],"senderShipments".*/\1/p'`
SENDERPART=`tr -d '\n' < "$SHIPFILE" | sed -n 's/.*"senderShipments":\[\(.*\)\]}.*/\1/p'`

# split a "[obj},{obj},...]" body (without outer brackets) into one object per line
split_objects() {
	printf '%s' "$1" | sed 's/},{/}\n{/g'
}

# track-and-trace for one shipment key -> writes colli object of the matching barcode to stdout (single line, or empty)
fetch_tt() {
	KEY="$1"; BARCODE="$2"
	TTF="$TMPDIR/postnl-tt.tmp"; removeFile "$TTF"
	curl $PROXY -s -k -A "$UA" -o "$TTF" -H "Authorization: Bearer $ACCESSTOKEN" "$TT_URL/$KEY?language=nl"
	tr -d '\n' < "$TTF" | sed -n 's/.*"'"$BARCODE"'":{\(.*\)},"processed".*/\1/p' | head -n 1
}

# Build one inbox entry (receiver or sender). Uses globals set by caller.
# Prints the json object for the entry.
build_entry() {
	OBJ="$1"; ROLE="$2"   # ROLE = receiver | sender

	BARCODE=`jsan "\`jstr "$OBJ" barcode\`"`
	KEY=`jstr "$OBJ" key`
	TITLE=`jsan "\`jstr "$OBJ" title\`"`
	STYPE=`jsan "\`jstr "$OBJ" shipmentType\`"`
	DELIVERED=`jval "$OBJ" delivered`
	DTS=`jsan "\`jstr "$OBJ" deliveredTimeStamp\`"`
	DWF=`jsan "\`jstr "$OBJ" deliveryWindowFrom\`"`
	DWT=`jsan "\`jstr "$OBJ" deliveryWindowTo\`"`

	# defaults
	STATUS="Open"
	SENDER_COMPANY="$TITLE"
	SENDER_LAST=""
	SENDER_TOWN=""
	PICKUP=""
	TF_FROM=""
	TF_TO=""
	DELDATE=""
	RCPT_STREET=""
	RCPT_HOUSE=""
	RCPT_TOWN=""
	TT_DELIVERED=""
	TT_RETURN=""
	TT_ATRETAIL=""
	TT_DELDATE=""

	# track & trace enrichment (best effort)
	COLLI=`fetch_tt "$KEY" "$BARCODE"`
	if [ -n "$COLLI" ]; then
		TT_DELIVERED=`jval "$COLLI" isDelivered`
		TT_RETURN=`jval "$COLLI" isReturnShipment`
		TT_ATRETAIL=`jval "$COLLI" isAtRetailLocation`
		TT_DELDATE=`jsan "\`jstr "$COLLI" deliveryDate\`"`
		# eta window
		ETA=`printf '%s' "$COLLI" | sed -n 's/.*"eta":{\([^}]*\)}.*/\1/p'`
		TF_FROM=`jsan "\`jstr "$ETA" start\`"`
		TF_TO=`jsan "\`jstr "$ETA" end\`"`
		# sender block town / names
		SBLOCK=`printf '%s' "$COLLI" | sed -n 's/.*"sender":{\(.*\)},"accountId".*/\1/p'`
		[ -z "$SBLOCK" ] && SBLOCK=`printf '%s' "$COLLI" | sed -n 's/.*"sender":{\(.*"town":[^,]*\),"country".*/\1/p'`
		S_COMPANY=`jsan "\`jstr "$SBLOCK" companyName\`"`
		S_PERSON=`jsan "\`jstr "$SBLOCK" personName\`"`
		SENDER_TOWN=`jsan "\`printf '%s' "$SBLOCK" | sed -n 's/.*"address":{[^}]*"town":"\([^"]*\)".*/\1/p'\`"`
		# recipient (for outgoing shipments)
		RADDR=`printf '%s' "$COLLI" | sed -n 's/.*"recipient":{[^}]*"address":{\([^}]*\)}.*/\1/p'`
		RCPT_STREET=`jsan "\`jstr "$RADDR" street\`"`
		RCPT_HOUSE=`jsan "\`jstr "$RADDR" houseNumber\`"`
		RCPT_TOWN=`jsan "\`jstr "$RADDR" town\`"`
		# retail pickup location name
		PICKUP=`jsan "\`printf '%s' "$COLLI" | sed -n 's/.*"retailDeliveryLocation":{[^}]*"name":"\([^"]*\)".*/\1/p'\`"`
		# prefer the more descriptive sender name from graphql title, else names from T&T
		if [ -z "$SENDER_COMPANY" ]; then
			if [ -n "$S_COMPANY" ]; then SENDER_COMPANY="$S_COMPANY"; else SENDER_LAST="$S_PERSON"; fi
		fi
	fi

	# decide status
	if [ "$DELIVERED" = "true" ] || [ "$TT_DELIVERED" = "true" ]; then
		STATUS="Delivered"
		DELDATE="$DTS"
		[ -z "$DELDATE" ] && DELDATE="$TT_DELDATE"
	elif [ "$TT_RETURN" = "true" ]; then
		STATUS="ReturnToSender"
	elif [ -n "$PICKUP" ] || [ "$TT_ATRETAIL" = "true" ]; then
		STATUS="InTransit"
	else
		# use eta window, fall back to graphql delivery window
		[ -z "$TF_FROM" ] && TF_FROM="$DWF"
		[ -z "$TF_TO" ] && TF_TO="$DWT"
		if [ -n "$TF_FROM" ]; then STATUS="Open"; else STATUS="InTransit"; fi
	fi
	# for delivered / open with graphql window, still expose the window when present
	[ -z "$TF_FROM" ] && TF_FROM="$DWF"
	[ -z "$TF_TO" ] && TF_TO="$DWT"

	if [ "$ROLE" = "receiver" ]; then
		printf '{"barcode":"%s","shipmentType":"%s","trackedShipment":{"title":"%s"},"delivery":{"status":"%s","deliveryDate":"%s","timeframe":{"from":"%s","to":"%s"}},"sender":{"companyName":"%s","lastName":"%s","town":"%s"},"deliveryLocation":{"name":"%s"}}' \
			"$BARCODE" "$STYPE" "$TITLE" "$STATUS" "$DELDATE" "$TF_FROM" "$TF_TO" "$SENDER_COMPANY" "$SENDER_LAST" "$SENDER_TOWN" "$PICKUP"
	else
		printf '{"barcode":"%s","shipmentType":"%s","trackedShipment":{"title":"%s"},"delivery":{"status":"%s","deliveryDate":"%s","timeframe":{"from":"%s","to":"%s"}},"originalReceiver":{"street":"%s","houseNumber":"%s","town":"%s"},"deliveryLocation":{"name":"%s"}}' \
			"$BARCODE" "$STYPE" "$TITLE" "$STATUS" "$DELDATE" "$TF_FROM" "$TF_TO" "$RCPT_STREET" "$RCPT_HOUSE" "$RCPT_TOWN" "$PICKUP"
	fi
}

TMPOUT="$TMPDIR/POSTNL-Inbox.json.tmp"
printf '{"receiver":[' > "$TMPOUT"

FIRST=1
if [ -n "$RECEIVERPART" ]; then
	split_objects "$RECEIVERPART" > "$TMPDIR/postnl-recv.tmp"
	while IFS= read -r line || [ -n "$line" ]
	do
		[ -z "$line" ] && continue
		ENTRY=`build_entry "$line" receiver`
		if [ -z "$ENTRY" ]; then continue; fi
		if [ $FIRST -eq 1 ]; then FIRST=0; else printf ',' >> "$TMPOUT"; fi
		printf '%s' "$ENTRY" >> "$TMPOUT"
	done < "$TMPDIR/postnl-recv.tmp"
fi

printf '],"sender":[' >> "$TMPOUT"

FIRST=1
if [ -n "$SENDERPART" ]; then
	split_objects "$SENDERPART" > "$TMPDIR/postnl-send.tmp"
	while IFS= read -r line || [ -n "$line" ]
	do
		[ -z "$line" ] && continue
		ENTRY=`build_entry "$line" sender`
		if [ -z "$ENTRY" ]; then continue; fi
		if [ $FIRST -eq 1 ]; then FIRST=0; else printf ',' >> "$TMPOUT"; fi
		printf '%s' "$ENTRY" >> "$TMPOUT"
	done < "$TMPDIR/postnl-send.tmp"
fi

printf ']}' >> "$TMPOUT"

# sanity check: must be non-empty and start with {"receiver"
if [ -s "$TMPOUT" ] && grep -q '^{"receiver"' "$TMPOUT"; then
	mv "$TMPOUT" "$INBOXFILE"
	echo "Succeeded: inbox json rebuilt from postnl"
	echo "`date '+%Y-%m-%d %H:%M:%S'`" > "$TMPDIR/lastupdate.log"
else
	echo "Warning: rebuilt inbox json looked invalid. Previous json kept."
	removeFile "$TMPOUT"
fi

# cleanup
if ! $DEBUG
then
	rm -f "$TMPDIR"/postnl-*.tmp
fi

# Done
