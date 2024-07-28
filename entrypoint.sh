#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" "$@"
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 $TAR_PACKAGE_OPERATION_MODIFIERS .

log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

remote_command="set -e;

workdir=\"\$HOME/workspace\";

log() {
    echo '>> [remote]' \$@ ;
};

if [ -d \$workdir ]
then
  log 'Deleting workspace directory...';
  rm -rf \$workdir;
fi

log 'Creating workspace directory...';
mkdir \$workdir;

log 'Unpacking workspace...';
tar -C \$workdir -xjv;

cd \$workdir;

log 'docker compose down...';
docker compose down

log 'moving secrets into workspace...';
rm -r secrets
mv ../secrets .

docker login -u \"$DOCKERHUB_USERNAME\" -p \"$DOCKERHUB_PASSWORD\"

log 'pulling...';
docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -f \"$DOCKER_COMPOSE_FILENAME_PRODUCTION\" -p \"$DOCKER_COMPOSE_PREFIX\" pull

docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -f \"$DOCKER_COMPOSE_FILENAME_PRODUCTION\" up -d;"

log "Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=100 \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
