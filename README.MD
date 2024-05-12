### Конфиг для docker-compose
```
  docker-containers-autostart:
    image: alexandreas/docker-containers-autostart:latest
    container_name: docker-containers-autostart
    restart: unless-stopped
    environment:
      - AUTOSTART_CONTAINERS=plex,transmission
    volumes:
      # host:container
      - /var/run/docker.sock:/var/run/docker.sock
```