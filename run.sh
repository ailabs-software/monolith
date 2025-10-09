
docker run --rm \
  --device /dev/fuse \
  --cap-add SYS_ADMIN \
  --publish 80:80 \
  --publish 8080:8080 \
  monolith
