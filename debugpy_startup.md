# Visual Studio Code debug configuration

```json
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Python: Remote Attach",
            "type": "python",
            "request": "attach",
            "connect": {
                "host": "localhost",
                "port": 5678
            },
            "pathMappings": [
                {
                    "localRoot": "${workspaceFolder}/glideinwms",
                    "remoteRoot": "/usr/lib/python3.6/site-packages/glideinwms"
                }
            ],
            "justMyCode": false,
            "subProcess": true
        },
        {
            "name": "Python: Current File",
            "type": "python",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal"
        }
    ]
}
```

# Debug Frontend
```sh
sudo -u frontend python3 -m debugpy --listen 0.0.0.0:5678 /opt/gwms-git/glideinwms/frontend/glideinFrontend.py /var/lib/gwms-frontend/vofrontend
```

# Debug Factory
```sh
(cd /var/lib/gwms-factory/work-dir; sudo -u gfactory python3 -m debugpy --listen 0.0.0.0:5678 /opt/gwms-git/glideinwms/factory/glideFactory.py /var/lib/gwms-factory/work-dir &)
```
