Simplied Mattermost docker app server.

ENV Vars (with defaults):

MM_SITE_URL="http://localhost:8000"
DB_HOST=db
DB_PORT=3306
DB_USE_SSL=disable
DB_USERNAME=mmuser
DB_PASSWORD=
DB_NAME=mattermost
DB_SQL_DRIVER=mysql
MM_CONFIG=/mattermost/config/config.json

To Run:

```
sudo docker run -d --name=mattermost \
  -v ./mattermost/data:/mattermost/data:z \
  -v ./mattermost/logs:/mattermost/logs:z \
  -v ./mattermost/config:/mattermost/config:z \
  -v ./mattermost/plugins:/mattermost/plugins:z \
  -v ./mattermost/client/plugins:/mattermost/client/plugins:z \
  -e DB_HOST="mattermostdb" \
  -e DB_PORT="3306" \
  -e DB_NAME="mattermost" \
  -e DB_USERNAME="mmuser" \
  -e DB_PASSWORD="your password" \
  -e DB_SQL_DRIVER="mysql" \
  -e MM_SITE_URL="https://mattermost.mydomain.com" \
 mattermost
```

Use the nginx example file to setup your nginx proxy


