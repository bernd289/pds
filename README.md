### Disclaimer

This is my personal repository and is provided for my own experiments and learning purposes.  
The code is provided **as-is**, without any warranty or guarantee of correctness or fitness for any purpose.  
You should not rely on this code or Docker image in production or for any critical use.

### Changes in this fork of https://github.com/bluesky-social/pds
- always the newest PDS and other deps
- Node 24
- based on [Docker Hardened Images](https://www.docker.com/blog/docker-hardened-images-for-every-developer) + [Socket Firewall](https://socket.dev/blog/socket-firewall-now-available-in-docker-hardened-images)
- I prefer using [goat](https://github.com/bluesky-social/goat) on the host system instead of including it in the cointainer
- few other little things
