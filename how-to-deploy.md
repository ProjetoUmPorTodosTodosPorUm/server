# How To Deploy on a Virtual Machine
I'm assuming you already have a VM and have root access to it. This setup is for Linux, tested in Debian 12.


## Name Server
After [updating your nameservers with your domain registrar](https://docs.digitalocean.com/products/networking/dns/getting-started/dns-registrars/), add the following [A and AAAA records](https://docs.digitalocean.com/products/networking/dns/how-to/manage-records/#create-update-and-delete-records-using-the-control-panel) poiting to your VM:
- ``projetoumportodostodosporum.org``
- ``wwww.projetoumportodostodosporum.org``
- ``api.projetoumportodostodosporum.org``
- ``cms.projetoumportodostodosporum.org``
- ``assets.projetoumportodostodosporum.org``
- ``files.projetoumportodostodosporum.org``


## Firewall
### Install UFW and configure the firewall
```bash
$ apt install ufw
$ ufw default deny incoming
$ ufw default allow outgoing
$ ufw allow ssh
# web
$ ufw allow 80/tcp
$ ufw allow 443/tcp
$ ufw allow 443/udp
$ ufw enable
```
You may verify the status of the firewall running ``$ ufw status``.


### UFW and Docker
Don't expose ports on Docker that shouldn't be exposed.


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
- ``SESSION_SECRET``

You may use ``.env.preview.example`` as reference. 
>**_Notice_** that **redis** and **postgresql** hosts are reached using the **service** names in docker-compose.yml file.


## Start the Web Application
- Inside the ``server`` directory, run ``$ ./scripts.sh start:prod`` 
- After the cointainers have been started, access the Server's container using ``$ docker exec -it --user root server sh``
- Inside Server's container run ``$ ./scripts.sh certbot:get-staging`` 
- If everything went well you can run ``$ ./scripts.sh certbot:get`` and ``$ ./scripts.sh nginx:https`` 


## Others

### Backup
See [Backup Docker Volumes](https://github.com/RenanGalvao/linux-scripts/tree/master/backup).


### Fail2Ban
- Install [Fail2ban](https://github.com/fail2ban/fail2ban) ``apt install fail2ban``
- Create a local config ``cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local``
- Change config to:
```
[DEFAULT]
backend = systemd

[sshd]
enabled = true
bantime = 4w
maxretry = 3

[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/*.log
backend  = polling

[nginx-bad-request]
enabled = true
port    = http,https
logpath = /var/log/nginx/access.log
backend = polling
bantime = 10m
maxretry = 5
```

### Editing OpenSSH Config
Create a backup of original config file ``cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak``.

<details>
  <summary>Set values to</summary>

- ``LogLevel VERBOSE`` Gives the verbosity level that is used when logging messages from SSH daemon.
- ``MaxAuthTries 3`` Specifies the maximum number of authentication attempts permitted per connection.
- ``MaxSessions 5`` Specifies the maximum number of open shell, login, or subsystem (e.g., SFTP) sessions allowed per network connection.
- ``HostbasedAuthentication no`` Specifies whether rhosts or /etc/hosts.equiv authentication together with successful public key client host authentication is allowed (host-based authentication).
- ``PermitEmptyPasswords no`` When password authentication is allowed, it specifies whether the server allows login to accounts with empty password strings.
- ``ChallengeResponseAuthentication yes``	Specifies whether challenge-response authentication is allowed.
- ``UsePAM yes`` Specifies if PAM modules should be used for authentification.
- ``X11Forwarding no`` Specifies whether X11 forwarding is permitted.
- ``PrintMotd no`` Specifies whether SSH daemon should print /etc/motd when a user logs in interactively.
- ``ClientAliveInterval 600``	Sets a timeout interval in seconds, after which if no data has been received from the client, the SSH daemon will send a message through the encrypted channel to request a response from the client.
- ``ClientAliveCountMax 0`` Sets the number of client alive messages which may be sent without SSH daemon receiving any messages back from the client.
- ``Protocol 2`` Specifies the usage of the newer protocol which is more secure.
- ``AuthenticationMethods publickey,keyboard-interactive`` Specifies the authentication methods that must be successfully completed for a user to be granted access.
- ``PasswordAuthentication no``	Specifies whether password authentication is allowed.
</details>

### Zram
```
apt install zram-tools
echo -e "ALGO=zstd\nPERCENT=50" | sudo tee -a /etc/default/zramswap
systemctl reload zramswap
```

### Sysctl
Create a backup of original config file ``cp /etc/sysctl.conf /etc/sysctl.conf.bak``.

<details>
  <summary>Add this to the end of the file:</summary>

```
# Custom
# Increase size of file handles and inode cache
fs.file-max = 2097152

### GENERAL NETWORK SECURITY OPTIONS ###

# Number of times SYNACKs for passive TCP connection.
net.ipv4.tcp_synack_retries = 2

# Allowed local port range
net.ipv4.ip_local_port_range = 2000 65535

# Protect Against TCP Time-Wait
net.ipv4.tcp_rfc1337 = 1

# Decrease the time default value for tcp_fin_timeout connection
net.ipv4.tcp_fin_timeout = 15

# Decrease the time default value for connections to keep alive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

### TUNING NETWORK PERFORMANCE ###

# Default Socket Receive Buffer
net.core.rmem_default = 31457280

# Maximum Socket Receive Buffer
net.core.rmem_max = 12582912

# Default Socket Send Buffer
net.core.wmem_default = 31457280

# Maximum Socket Send Buffer
net.core.wmem_max = 12582912

# Increase number of incoming connections
net.core.somaxconn = 4096

# Increase number of incoming connections backlog
net.core.netdev_max_backlog = 65536

# Increase the maximum amount of option memory buffers
net.core.optmem_max = 25165824

# Increase the maximum total buffer-space allocatable
# This is measured in units of pages (4096 bytes)
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144

# Increase the read-buffer space allocatable
net.ipv4.tcp_rmem = 8192 87380 16777216
net.ipv4.udp_rmem_min = 16384

# Increase the write-buffer-space allocatable
net.ipv4.tcp_wmem = 8192 65536 16777216
net.ipv4.udp_wmem_min = 16384

# Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
```
</details>

then ``sysctl -p``.