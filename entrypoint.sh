#!/bin/sh

# Function to generate a random salt
generate_salt() {
  tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 48 | head -n 1
}

echo "Welcome"

# Read environment variables or set default values
MM_SITE_URL=${MM_SITE_URL:-"http://localhost:8000"}
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
DB_USE_SSL=${DB_USE_SSL:-disable}
DB_NAME=${DB_NAME:-mattermost}
DB_SQL_DRIVER=${DB_SQL_DRIVER:-mysql}
MM_CONFIG=${MM_CONFIG:-/mattermost/config/config.json}


_1=$(echo "$1" | awk '{ s=substr($0, 0, 1); print s; }')
if [ "$_1" = '-' ]; then
  set -- mattermost "$@"
fi

if [ "$1" = 'mattermost' ]; then
  # Check CLI args for a -config option
  for ARG in "$@"; do
    case "$ARG" in
    -config=*) MM_CONFIG=${ARG#*=} ;;
    esac
  done

  if [ ! -f "$MM_CONFIG" ]; then
    # If there is no configuration file, create it with some default values
    echo "No configuration file $MM_CONFIG"
    echo "Creating a new one"
    # Copy default configuration file
    cp /config.json.save "$MM_CONFIG"
    # Substitute some parameters with jq
    jq ".ServiceSettings.SiteURL = \"$MM_SITE_URL\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq ".ServiceSettings.ListenAddress = \":8000\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.LogSettings.EnableConsole = true' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.LogSettings.ConsoleLevel = "ERROR"' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.FileSettings.Directory = "/mattermost/data/"' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.FileSettings.EnablePublicLink = true' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq ".FileSettings.PublicLinkSalt = \"$(generate_salt)\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.EmailSettings.SendEmailNotifications = false' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.EmailSettings.FeedbackEmail = ""' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.EmailSettings.SMTPServer = ""' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.EmailSettings.SMTPPort = ""' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq ".EmailSettings.InviteSalt = \"$(generate_salt)\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq ".EmailSettings.PasswordResetSalt = \"$(generate_salt)\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.RateLimitSettings.Enable = true' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq ".SqlSettings.DriverName = \"${DB_SQL_DRIVER}\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq ".SqlSettings.AtRestEncryptKey = \"$(generate_salt)\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    jq '.PluginSettings.Directory = "/mattermost/plugins/"' "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
  else
    echo "Using existing config file $MM_CONFIG"
  fi

  # Configure database access
  if [ -z "$MM_SQLSETTINGS_DATASOURCE" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
    echo "Configure database connection..."

    
    if [ ${DB_SQL_DRIVER} = "mysql" ]; then
       export MM_SQLSETTINGS_DATASOURCE="${DB_USERNAME}:${DB_PASSWORD}@tcp(${DB_HOST}:${DB_PORT})/${DB_NAME}?charset=utf8mb4,utf8\u0026readTimeout=30s\u0026writeTimeout=30s"
       jq ".SqlSettings.DataSource = \"${MM_SQLSETTINGS_DATASOURCE}\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    else
       # URLEncode the password, allowing for special characters
       ENCODED_PASSWORD=$(printf %s "$DB_PASSWORD" | jq -s -R -r @uri)

       export MM_SQLSETTINGS_DATASOURCE="postgres://$DB_USERNAME:$ENCODED_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=$DB_USE_SSL&connect_timeout=10"
       jq ".SqlSettings.DataSource = \"${MM_SQLSETTINGS_DATASOURCE}\"" "$MM_CONFIG" >"$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
   fi

    echo "OK"
  else
    echo "Using existing database connection"
  fi

  # Wait another second for the database to be properly started.
  # Necessary to avoid "panic: Failed to open sql connection: the database system is starting up"
  sleep 1

  echo "Starting mattermost"
fi

exec "$@"
