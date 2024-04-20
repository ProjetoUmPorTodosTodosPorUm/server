# How To Deploy on a Virtual Machine
I'm assuming you already have a VM and have root access to it. This setup is for Linux, tested in Debian 12.


## Name Server
After [updating your nameservers with your domain registrar](https://docs.digitalocean.com/products/networking/dns/getting-started/dns-registrars/), add the following [A and AAAA records](https://docs.digitalocean.com/products/networking/dns/how-to/manage-records/#create-update-and-delete-records-using-the-control-panel) poiting to your VM:
- ``projetoumportodostodosporum.org``
- ``wwww.projetoumportodostodosporum.org``
- ``api.projetoumportodostodosporum.org``
- ``www.api.projetoumportodostodosporum.org``
- ``cms.projetoumportodostodosporum.org``
- ``www.cms.projetoumportodostodosporum.org``
- ``assets.projetoumportodostodosporum.org``
- ``www.assets.projetoumportodostodosporum.org``
- ``files.projetoumportodostodosporum.org``
- ``www.files.projetoumportodostodosporum.org``


## Firewall
### Install UFW and configure the firewall
```bash
$ apt install ufw
$ ufw default deny incoming
$ ufw default allow outgoing
$ ufw allow ssh
$ ufw allow 80
$ ufw allow 443/tcp
$ ufw allow 443/udp
$ ufw enable
```
You may verify the status of the firewall running ``$ ufw status``.


### UFW and Docker
Since [ufw and Docker doesn't work together](https://www.howtogeek.com/devops/how-to-use-docker-with-a-ufw-firewall/), modify UFW's config at ``/etc/ufw/after.rules`` to add the following block at the end:
```
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN

-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
```
Then restart UFW: ``$ systemctl restart ufw``.


## Docker
Install [Docker Engine with Docker Compose](https://docs.docker.com/engine/install/) then get access to your registry:
- With [Docker Hub](https://hub.docker.com/)
    - Create a new [access token](https://docs.docker.com/security/for-developers/access-tokens/) and save it
    - Run from your VM: ``$ docker login -u your_username`` 
    - At the password prompt, enter the personal access token


## Code Repository Access
- Install [Git](https://git-scm.com/) 
- Create a new ssh key using ``ssh-keygen`` 
- [Add the public key to the github account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) that manages the repositories.
- Clone this repository


## Create [Environment Vars](https://help.ubuntu.com/community/EnvironmentVariables#Session-wide_environment_variables) for the Application

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

You may use ``.env.preview.example`` as reference. 
>**_Notice_** that **redis** and **postgresql** hosts are reached using the **service** names in docker-compose.yml file.

## Start the Web Application
- Inside the ``server`` directory, run ``$ ./scripts.sh start:prod`` 
- After the cointainers have been started, access the server's container using ``$ docker exec -it --user root server sh``
- Inside server's container run ``$ ./scripts.sh certbot:get-staging`` 
- If everything went well you can run ``$ ./scripts.sh certbot:get`` and ``$ ./scripts.sh nginx:https`` 


 
    

