#!/bin/sh

# Solve2Surf FAS (Forwarding Authentication Service)
# This script sits behind uhttpd, reads form POSTs, validates against the local/public problems,
# interfaces with OpenNDS for auth, and renders the frontend HTML.

. /lib/functions.sh

PROBLEMS_FILE="/tmp/solve2surf_problems.json"
SPLASH_TEMPLATE="/www/solve2surf/splash.html"

# Render HTML using sed templating
send_page() {
    local state="$1"
    local p_id="$2"
    local p_text="$3"
    local duration="$4"
    local sys_msg="$5"

    # Escape quotes and backslashes for JS string injection
    # We use sed to replace " with \" and handle basic escaping.
    p_text=$(echo "$p_text" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    sys_msg=$(echo "$sys_msg" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    echo "Content-Type: text/html"
    echo "Cache-Control: no-cache, must-revalidate"
    echo ""
    
    if [ -f "$SPLASH_TEMPLATE" ]; then
        sed -e "s/{{STATE}}/$state/g" \
            -e "s/{{P_ID}}/$p_id/g" \
            -e "s/{{P_TEXT}}/$p_text/g" \
            -e "s/{{DURATION}}/$duration/g" \
            -e "s/{{SYS_MSG}}/$sys_msg/g" \
            "$SPLASH_TEMPLATE"
    else
        # Fallback if the template is literally missing from the router
        echo "<html><body><h1>Solve & Surf Error</h1><p>Missing splash.html template file.</p></body></html>"
    fi
}

# 1. Extract OpenNDS Parameters from Query String
PARAM_STR="$QUERY_STRING"
C_IP=$(echo "$PARAM_STR" | grep -o 'clientip=[^&]*' | cut -d= -f2)
C_MAC=$(echo "$PARAM_STR" | grep -o 'clientmac=[^&]*' | cut -d= -f2)

# Safety check - No IP means it's not a genuine OpenNDS captive portal redirect
if [ -z "$C_IP" ]; then
    send_page "SYS_ERROR" "" "" "" "Invalid portal request: Missing client IP."
    exit 0
fi

# 2. Handle Form Submission (POST)
if [ "$REQUEST_METHOD" = "POST" ]; then
    read -r POST_DATA
    
    # URL decode the answer
    USER_ANSWER=$(echo "$POST_DATA" | grep -o 'answer=[^&]*' | cut -d= -f2 | sed 's/+/ /g' | sed 's/%[0-9A-F][0-9A-F]/\\x&/g' | xargs -0 printf '%b')
    P_ID=$(echo "$POST_DATA" | grep -o 'p_id=[^&]*' | cut -d= -f2)

    # Re-fetch the exact problem JSON the user is trying to solve
    PROBLEM_JSON=$(jsonfilter -i "$PROBLEMS_FILE" -e "@[@.id=\"$P_ID\"]")
    P_TYPE=$(echo "$PROBLEM_JSON" | jsonfilter -e '@.type')
    P_DURATION=$(echo "$PROBLEM_JSON" | jsonfilter -e '@.duration_minutes')
    P_TEXT=$(echo "$PROBLEM_JSON" | jsonfilter -e '@.question')

    logger -t solve2surf "POST: id=$P_ID type=$P_TYPE answer=$USER_ANSWER"
    VALID=0

    if [ "$P_TYPE" = "local" ]; then
        EXPECTED=$(echo "$PROBLEM_JSON" | jsonfilter -e '@.expected_answer')

        logger -t solve2surf "Local Check: expected=$EXPECTED actual=$USER_ANSWER"
        
        # Case-insensitive validation
        USER_LOWER=$(echo "$USER_ANSWER" | awk '{print tolower($0)}')
        EXPECTED_LOWER=$(echo "$EXPECTED" | awk '{print tolower($0)}')
        if [ -n "$EXPECTED_LOWER" ] && [ "$USER_LOWER" = "$EXPECTED_LOWER" ]; then
            VALID=1
        fi
        
    elif [ "$P_TYPE" = "public" ]; then
        ENDPOINT=$(echo "$PROBLEM_JSON" | jsonfilter -e '@.grading_endpoint')
        MIN_SCORE=$(echo "$PROBLEM_JSON" | jsonfilter -e '@.min_passing_score')

        # Since it's public API grading, curl the external service
        API_RESP=$(curl -s --max-time 10 -X POST -d "answer=$USER_ANSWER" "$ENDPOINT")
        ACTUAL_SCORE=$(echo "$API_RESP" | jsonfilter -e '@.score')

        logger -t solve2surf "API Check: score=$ACTUAL_SCORE (min=$MIN_SCORE)"
        if [ -n "$ACTUAL_SCORE" ] && [ "$ACTUAL_SCORE" -ge "$MIN_SCORE" ]; then
            VALID=1
        fi
    fi

    # Render Outcome
    if [ "$VALID" -eq 1 ]; then
        ndsctl auth "$C_IP" "$P_DURATION" > /dev/null 2>&1
        send_page "SUCCESS" "" "" "$P_DURATION" ""
    else
        # Render the 'ERROR' state so UI can shake and display "Try Again"
        send_page "ERROR" "$P_ID" "$P_TEXT" "" ""
    fi
    exit 0
fi

# 3. Handle Challenge Display (GET)

if [ ! -f "$PROBLEMS_FILE" ]; then
    send_page "SYS_ERROR" "" "" "" "Please wait while we fetch the latest problem set..."
    exit 0
fi

# Count how many problems exist
COUNT=$(jsonfilter -i "$PROBLEMS_FILE" -e '@[*]' | wc -l)

if [ -z "$COUNT" ] || [ "$COUNT" -eq 0 ]; then
    send_page "SYS_ERROR" "" "" "" "The problem set is empty. Please check your system storage settings."
    exit 0
fi

# Pick a universally random problem
INDEX=$(( $(head /dev/urandom | tr -dc 0-9 | head -c 4) % COUNT ))

PROBLEM=$(jsonfilter -i "$PROBLEMS_FILE" -e "@[$INDEX]")
P_ID=$(echo "$PROBLEM" | jsonfilter -e '@.id')
P_TEXT=$(echo "$PROBLEM" | jsonfilter -e '@.question')

# Send the initial 'CHALLENGE' state to the UI
send_page "CHALLENGE" "$P_ID" "$P_TEXT" "" ""
