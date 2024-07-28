#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" "$@"
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
}
trap cleanup EXIT

log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

remote_command="set -e;

workdir=\"\$HOME/workspace\";

log() {
    echo '>> [remote]' \$@ ;
};

mkdir -p \$workdir;
cd \$workdir;

if [ -e $DOCKER_COMPOSE_FILENAME ]
then
  log 'docker compose down...';
  docker compose down;
  
  log 'deleting old compose/secret files...';
  rm -r /secrets;
  rm -f $DOCKER_COMPOSE_FILENAME;
  rm -f $DOCKER_COMPOSE_FILENAME_PRODUCTION;
fi

if [ -e volumes ]
then
  log 'using the existing volume mounts on the remote...';
  rm -r ../volumes
else
  log 'adding the repo's volume mounts to the remote, as it doesn't exist...';
  mv ../volumes .
fi

mv ../$DOCKER_COMPOSE_FILENAME .
mv ../$DOCKER_COMPOSE_FILENAME_PRODUCTION .

log 'moving secrets into workspace...';
mv ../secrets .

docker login -u \"$DOCKERHUB_USERNAME\" -p \"$DOCKERHUB_PASSWORD\"

log 'pulling...';
docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -f \"$DOCKER_COMPOSE_FILENAME_PRODUCTION\" -p \"$DOCKER_COMPOSE_PREFIX\" pull

docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -f \"$DOCKER_COMPOSE_FILENAME_PRODUCTION\" up -d;"

log "Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=100 \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
