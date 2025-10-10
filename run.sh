
docker run --rm \
  --device /dev/fuse \
  --cap-add SYS_ADMIN \
  --publish 80:80 \
  --publish 8080:8080 \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  monolith
