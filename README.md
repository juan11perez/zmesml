# zmesml


docker container for zoneminder + zmeventserver + mlapi
```
  zm136:
    container_name: zm136
    image: juan11perez/zmesml
    restart: unless-stopped
    hostname: UNRAID  
    runtime: nvidia
    network_mode: "bridge"
    privileged: false
    shm_size: '8gb'   
    volumes:
    - /mnt/cache/appdata/cctv/zm136/config:/config:rw
    - /usr/local/cuda:/usr/local/cuda
    - type: bind
      source: /mnt/disks/storage/cctv/zm136
      target: /var/cache/zoneminder
      bind:
        propagation: slave 
    env_file: secrets/.zoneminder   
    ports:
    - 8088:80/tcp #http view     # - 8444:443/tcp     
    - 9000:9000/tcp
    - 5002:5000    
    healthcheck:
      test: ["CMD", "curl", "-fk", "http://192.168.1.100:8088/zm"]
      interval: 30s
      timeout: 10s
      retries: 5  
    deploy:
      resources:
        reservations:
          devices:
          - capabilities: ["gpu"]
            device_ids: ["GPU-XXXXXXXXXXXXXXXXXXXXXXXXXXX"]        
    devices:
    - /dev/apex_0:/dev/apex_0
    
```
Create user in the persistent config volume with below commands:

```
docker exec -it zm136 /bin/bash
```
```
cd /config/db && python3 /var/lib/zmeventnotification/mlapi_dbuser.py
```

