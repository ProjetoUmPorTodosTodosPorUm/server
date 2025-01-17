# Server
Server component of [projetoumportodostodosporum.org's](https://projetoumportodostodosporum.org) website.


## Dependencies
- [Docker Engine with Docker Compose](https://docs.docker.com/engine/install/)


## Environment Vars
### Development
Create a copy from ``.env.dev.example`` file in the root folder and rename to ``.env.dev`` and update it accordingly.

### Preview
Same as above using ``.env.preview.example`` file.

### Production
You need to [set these variables session-wide](https://help.ubuntu.com/community/EnvironmentVariables#Session-wide_environment_variables):
- ``ACCESS_TOKEN_JWT_SECRET``
- ``REFRESH_TOKEN_JWT_SECRET``
- ``MAIL_HOST``
- ``MAIL_PORT``
- ``MAIL_USER``
- ``MAIL_PASSWORD``
- ``MAIL_FROM``
- ``DATABASE_URL``
- ``DB_USER``
- ``DB_PASSWORD``
- ``REDIS_HOST``
- ``REDIS_PORT``
- ``SESSION_SECRET``


## Run
### Development
```bash
./scripts.sh start:dev
```
### Preview
```bash
./scripts.sh start:preview
```
### Production
```bash
./scripts.sh start:prod
```


## Build
### Preview
```bash
./scripts.sh build:preview
```
### Production
```bash
./scripts.sh build:prod
```


## Certbot
Inside Server's container as root user: ``docker exec -it --user root server sh``.

- ``./scripts.sh certbot:renew``       - Cerbot renew process
- ``./scripts.sh certbot:renew-dry``   - Cerbot renew test process
- ``./scripts.sh certbot:get``         - obtain SSL certificates
- ``./scripts.sh certbot:get-staging`` - certbot:get staging


### Setting up HTTPS for the first time
- ``certbot:get-staging`` - verify if everything is ok
- ``certbot:get`` - get certificates 
- ``nginx:https`` - update nginx configuration files 


## Nginx
Inside Server's container as root user: ``docker exec -it --user root server sh``.

- ``./scripts.sh nginx:http``          - change server conf to http only (pre SSL certificates)
- ``./scripts.sh nginx:https``         - change server conf to https (post SSL certificates)



## Related Repositories
- [Backend](https://github.com/ProjetoUmPorTodosTodosPorUm/api) (api)
- [Website](https://github.com/ProjetoUmPorTodosTodosPorUm/web) (web)
- [Content Management](https://github.com/ProjetoUmPorTodosTodosPorUm/cms) (cms)
