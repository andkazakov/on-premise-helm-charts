#!/bin/bash
set -e
set -u 
set -o pipefail

SCRIPTPATH=$(dirname `readlink -f "$0"`)

URL=$1
KEY=$2
i=0
cd $SCRIPTPATH/points

TASK_ID=`curl -s $URL/create_task/get_dist_matrix?key=$KEY --header 'Content-Type: application/json' -d @moscow_dm.json | jq -r '.task_id'`
echo "Start test Moscow"
echo "Create task with ID" $TASK_ID
sleep 5
function task_status() {
  echo `curl -s $URL/result/get_dist_matrix/$TASK_ID?key=$KEY | jq -r '.status'`
}

function task_response() {
  LINK=`curl -s $URL/result/get_dist_matrix/$TASK_ID?key=$KEY | jq -r '.result_link'`
  if [[ $LINK == "" ]] ;then
    echo "response.json not found on s3, check settings s3 on navi-back-async" && exit 1
  else
    response=`curl -s $LINK`
    echo -e $response $'\n'
    response_status=`echo $response | jq .routes[].status | grep OK | wc -l`
    if [[ $response_status -ge "1" ]]; then
      echo "OK"
    else
      echo "No successful routes" && exit 1
    fi
  fi
}

echo "Task status" `task_status`
while [[ `task_status` != "TASK_DONE" && "$i" -lt "5" ]]; do
  i=$[ $i + 1 ]
  echo "Wait..."
  sleep 10
done

if [[ "$i" -ge "5" ]] || [[ `task_status` != "TASK_DONE" ]];then
  echo "Task status" `task_status`
  echo "Long task processing, check logs navi-async-service and navi-back-async" && exit 1
elif [[ `task_status` == "TASK_DONE" ]];then
  echo "Task status" `task_status`
  task_response
fi
