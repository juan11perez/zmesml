#!/bin/bash
ZM_TOKEN='token'
EVENT_ID=`echo ${6} | awk -F'/' '{ print $8 }'`
MESSAGE=`echo ${4} | sed -e 's/.*] \(.*\)Motion.*/\1/'`
CAMERA=$3
GOTI_HOST='https://mygotifydomain'
GOTI_TKN='token'
ZM_PORTAL='https://myzmdomain/zm'
CONNKEY=${RANDOM}${RANDOM}

if [[ "$MESSAGE" != "Motion: All" ]] && [[ "$3" == "doorbell" ]]; then
# if [[ "$MESSAGE" != "Motion: All" ]]; then

  curl --silent -S --request POST \
    --url "${GOTI_HOST}/message?token=${GOTI_TKN}" \
    --header 'content-type: application/json' \
    --data "{
        \"title\": \"ZM136 - ${CAMERA^} Camera\",
        \"message\": \"${MESSAGE}\n\n[View event in browser](${ZM_PORTAL}/cgi-bin/nph-zms?mode=jpeg&frame=1&replay=none&source=event&event=${EVENT_ID}&connkey=${CONNKEY}&token=${ZM_TOKEN})\n\n![Camera Image](${ZM_PORTAL}/index.php?view=image&eid=${EVENT_ID}&fid=objdetect&popup=1&token=${ZM_TOKEN})\",
        \"priority\": 6,
          \"extras\": {
        \"client::display\": {
          \"contentType\": \"text/markdown\",
        \"client::notification\": {
          \"click\": \"{ 'url': '${ZM_PORTAL}/cgi-bin/nph-zms?mode=jpeg&frame=1&replay=none&source=event&event=${EVENT_ID}&connkey=77493&token=${ZM_TOKEN}'}\"
        }
      }
    }
  }"

fi
