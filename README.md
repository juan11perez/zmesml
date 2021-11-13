# zmesml


docker container for zoneminder + zmeventserver + mlapi
```
  neozmesml:
    container_name: neozmesml
    image: juan11perez/neozmesml
    restart: unless-stopped
    hostname: UNRAID  
    runtime: nvidia
    network_mode: "bridge"
    privileged: false
    shm_size: '8gb'   
    volumes:
    - /mnt/cache/appdata/cctv/neozmesml/config:/config:rw
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
docker exec -it neozmesml /bin/bash
```
```
cd /config && python3 /var/lib/zmeventnotification/mlapi_dbuser.py -u mlapitest -p test123
```

