# devart.lua

Very basic lua script for accessing the deviantart api. It requires that you first install libUseful and libUseful-lua.

# AUTHOR

Colum Paget (colums.projects@gmail.com)

# LICENCE

This script is licenced under the GPL v3

# USAGE

When you first run the script it will instruct you to paste a URL into your browser and log into deviantart. Deviantart should then ask you to confirm that you want to allow the script to access your account, and will then callback to the script on port 8989 of localhost to finalize the authorization. 

Once that's done you should be able to user the script thusly:


```
        lua devart.lua notify [no of pages]              display user notifications
        lua devart.lua faves                             display favorities per deviation
        lua devart.lua comments                          display comments per deviation
        lua devart.lua notes                             display notes sent to the user
```

# PROXIES

You can set a proxy URL in any of the following environment variables.

```
SOCKS_PROXY
socks_proxy
HTTPS_PROXY
https_proxy
all_proxy
devart_proxy
```

Proxy URLs can be of the form:

https://<user>:<pass>@<host>:<port>       HTTPS Connect proxy
socks4://<user>:<pass>@<host>:<port>      Socks4 proxy
socks5://<user>:<pass>@<host>:<port>      Socks5 proxy
sshtunnel://<user>:<pass>@<host>:<port>   Proxy through a tunnel to an SSH server
