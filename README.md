# Server
Server component of [projetoumportodostodosporum.org's](https://projetoumportodostodosporum.org) website.

## Dependencies
- [Docker Engine with Docker Compose](https://docs.docker.com/engine/install/)
- [OpenSSL for Linux](https://www.openssl.org/source/)
- add ``localhost.crt`` (generated after ``start:dev``) as "certificate authority" in your browser


## Environment Vars
### Development
Create a copy from ".env.dev.example" file in the root folder and rename to ".env.dev" and update it accordingly.

### Preview
Same as above using ".env.preview.example" file.

## Run
### Development
```bash
$ ./scripts.sh start:dev
```
### Preview
```bash
$ ./scripts.sh start:preview
```
### Production
```bash
$ ./scripts.sh start:prod
```
For development and preview mode you need to generate a certificate and trust systemwide:
```bash
$ ./scripts.sh openssl:certificate
$ sudo ./scripts.sh openssl:trust
```


## Build
### Preview
```bash
$ ./scripts.sh build:preview
```
### Production
```bash
$ ./scripts.sh build:prod
```


## Certbot
>Inside Server's container as root
```sh
$ ./scripts.sh certbot:renew       - Cerbot renew process
$ ./scripts.sh certbot:renew-dry   - Cerbot renew test process
$ ./scripts.sh certbot:get         - obtain SSL certificates
$ ./scripts.sh certbot:get-staging - certbot:get staging
```
### Setting up HTTPS for the first time
- ``certbot:get-staging`` - verify if everything is ok
- ``certbot:get`` - get certificates 
- ``nginx:https`` - update nginx configuration files 
- ``certbot:renew-dry`` - verify if auto renew is up


## Nginx
>Inside Server's container as root
```sh
$ ./scripts.sh nginx:http          - change server conf to http only (pre SSL certificates)
$ ./scripts.sh nginx:https         - change server conf to https (post SSL certificates)
```


## Access Server's container as root
```bash
$ docker exec -it --user root server sh
```

## Related Repositories
- [Backend](https://github.com/ProjetoUmPorTodosTodosPorUm/api) (api)
- [Website](https://github.com/ProjetoUmPorTodosTodosPorUm/web) (web)
- [Content Management](https://github.com/ProjetoUmPorTodosTodosPorUm/cms) (cms)
