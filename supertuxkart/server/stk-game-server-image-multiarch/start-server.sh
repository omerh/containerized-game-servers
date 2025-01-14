#!/bin/bash -x

trap sighandler TERM QUIT EXIT KILL

sighandler () {
  echo -en "\n## Caught SIGTERM\n";
  if [ "$IS_AGONES" = "True" ]; then
    curl -s -d "{}" -H "Content-Type: application/json" -X POST http://localhost:${AGONES_SDK_HTTP_PORT}/shutdown
    echo -en "called to http://localhost:${AGONES_SDK_HTTP_PORT}/shutdown"
  fi
  exit $?
}

public_ipv4=`/get-public-ipv4.py`

if [ "$IS_AGONES" = "True" ]; then
  game_server_port=$GAME_SERVER_PORT
  game_server_ip="localhost"
else
  game_server_port=`/get-port.py`
  game_server_ip=$public_ipv4
fi

echo export UDP_SOCKET_PORT=$game_server_port >> /root/.bashrc 
echo export UDP_SOCKET_IP=$game_server_ip >> /root/.bashrc

public_port=`curl -s -H "Content-Type: application/json" -X GET http://localhost:${AGONES_SDK_HTTP_PORT}/gameserver| jq '.status.ports[].port'`

while [ -z $public_port ]; do
  sleep 5
  public_port=`curl -s -H "Content-Type: application/json" -X GET http://localhost:${AGONES_SDK_HTTP_PORT}/gameserver| jq '.status.ports[].port'`
done

endpoint=$public_ipv4:$public_port
#update endpoint for the srv-sigstop.sh
echo export ENDPOINT=$endpoint >> /root/.bashrc

game_track=`/get-track.py`

game_mode=`/get-mode.py`

game_location=`/get-location.py`

game_difficulty=`echo $(( RANDOM % 4 ))`

game_theme_track=`psql -A -q -t -w -c "/*start-server.sh*/select theme from trackmap where track='$game_track';"|sed 's/ //g'`

game_max_players=`awk -v min=36 -v max=64 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`

laps=`awk -v min=10 -v max=19 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`

id=`psql -A -q -t -w -c "/*start-server.sh*/insert into servers(created_at,updated_at,location,endpoint,mode,track,tracktheme,max_players,difficulty,is_ready,pod_name) values (NOW(),NOW(),'$game_location','"$endpoint"','$game_mode','$game_track','$game_theme_track','$game_max_players','$game_difficulty',1,'$POD_NAME') returning id;"`
echo "psql exit code="$?
if [ -z "$id" ]
then
  echo "ERR-DB"
fi

cd /stk-code
./cmake_build/bin/supertuxkart --server-config=/server_config.xml --port=$game_server_port $MISC_ARGS --difficulty=$game_difficulty --max-players=$game_max_players --track=$game_track --laps=$laps &
/monitor-sessions.sh
