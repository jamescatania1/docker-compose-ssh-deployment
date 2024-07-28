#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" "$@"
}

cleanup() {
  set +e
  log "killing ssh agent..."
  ssh-agent -k
}
trap cleanup EXIT

log "launching ssh agent..."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

log "sending the root compose and volumes default files to the remote..."
scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=100 -P "$SSH_PORT" \
  volumes "$SSH_USER@$SSH_HOST:/var/lib/docker-deploy/volumes"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=100 -P "$SSH_PORT" \
  $DOCKER_COMPOSE_FILENAME "$SSH_USER@$SSH_HOST:/var/lib/docker-deploy/$DOCKER_COMPOSE_FILENAME"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=100 -P "$SSH_PORT" \
  $DOCKER_COMPOSE_FILENAME_PRODUCTION "$SSH_USER@$SSH_HOST:/var/lib/docker-deploy/$DOCKER_COMPOSE_FILENAME_PRODUCTION"
  
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
fi

if [ -z "$( ls -A './volumes' )" ]
then
  log 'adding the repo's volume mounts to the remote, as it doesn't exist...';
  cp ../volumes/* ./volumes/
else
  log 'using the existing volume mounts on the remote...';
fi

mv ../$DOCKER_COMPOSE_FILENAME .
mv ../$DOCKER_COMPOSE_FILENAME_PRODUCTION .

log 'moving secrets into workspace...';
mv ../secrets/* ./secrets/*

log 'deleting the temporary files...';
rm -r ../secrets
rm -r ../volumes

docker login -u \"$DOCKERHUB_USERNAME\" -p \"$DOCKERHUB_PASSWORD\"

log 'pulling...';
docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -f \"$DOCKER_COMPOSE_FILENAME_PRODUCTION\" -p \"$DOCKER_COMPOSE_PREFIX\" pull

docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -f \"$DOCKER_COMPOSE_FILENAME_PRODUCTION\" up -d;"

log "Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=100 \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
