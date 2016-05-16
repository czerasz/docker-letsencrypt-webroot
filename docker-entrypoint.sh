#!/bin/bash

# Check if the certificate is about to expire.
# 30 days before the expiration date trigger the renewal.
#
# Resource: https://gist.github.com/thisismitch/e1b603165523df66d5cc/

# Define Let's Encrypt configuration file
configuration_file='/etc/letsencrypt/cli.ini'

# If the environment variables $DOMAINS and $EMAIL are defined
# and the configuration file is not shared, create configuration file from template/example
if [ ! -z "$DOMAINS" ] && [ ! -z "$EMAIL" ] && [ ! -f "$configuration_file" ]; then
  # Rename cli.ini.example (template) to configuration file
  mv /etc/default/letsencrypt/cli.ini.example $configuration_file
  # Replace the email
  sed -i 's/email \= contact\@yourdomain\.com/email \= '"$EMAIL"'/' $configuration_file
  # Replace the domains
  sed -i 's/domains \= yourdomain\.com\,www\.yourdomain\.com/domains \= '"$DOMAINS"'/' $configuration_file
fi

# Define Let's Encrypt webroot path
webroot_path='/etc/letsencrypt/webroot/'

# Define the renewal expiration limit
if [ -z "$RENEW_BEFORE_DAY_LIMIT" ] ; then
  # Set default value
  # Trigger renewal 30 days before it expires
  renew_before_day_limit=30;
else
  renew_before_day_limit=$RENEW_BEFORE_DAY_LIMIT
fi

# Check if configuration file exists
if [ ! -f $configuration_file ]; then
  echo "[ERROR] config file does not exist: $configuration_file"
  exit 1;
fi

# Get the first domain used for the certificate
domain=`grep "^\s*domains" $configuration_file | sed "s/^\s*domains\s*=\s*//" | sed 's/(\s*)\|,.*$//'`

# Specify the path to the certificate
certificate_file="/etc/letsencrypt/live/$domain/fullchain.pem"

# Check if the certificate file exists
if [ ! -f $certificate_file ]; then
  echo "[ERROR] certificate file not found for domain $domain."
else
  # Get the expiration date of the certificate
  exp=$(date -d "`openssl x509 -in $certificate_file -text -noout|grep "Not After"|cut -c 25-`" +%s)
  datenow=$(date -d "now" +%s)

  # Calculate how many days the certificate is valid
  days_exp=$(( ${exp}-${datenow} ))
  days_exp=$(( ${days_exp}/86400 ))

  echo "Checking expiration date for $domain..."

  if [ "$days_exp" -gt "$renew_before_day_limit" ] ; then
    echo "The certificate is up to date, no need for renewal ($days_exp days left)."
    exit 0;
  else
    echo "The certificate for $domain is about to expire soon ($days_exp days left)."
  fi
fi

# Create webroot directory if it doesn't exist
if [ ! -d "$webroot_pathetc/letsencrypt/webroot" ]; then
  mkdir -p $webroot_path
fi

echo "Starting webroot renewal script..."

# Pass arguments passed to the script
certbot certonly --config $configuration_file --webroot-path $webroot_path $@

# For testing use:
# ```
# certbot certonly --test-cert --config /etc/letsencrypt/cli.ini
# ```

# If $USER environment variable was defined use it to change file ownership
if [ ! -z "$USER" ]; then
  # If $GROUP environment variable was defined use it to change file ownership
  if [ ! -z "$GROUP" ]; then
    chown $USER:$GROUP -R /etc/letsencrypt
  else
    chown $USER -R /etc/letsencrypt
  fi
fi

# If $UID environment variable was defined use it to change file ownership
if [ ! -z "$UID" ]; then
  # If $GID environment variable was defined use it to change file ownership
  if [ ! -z "$GID" ]; then
    chown $UID:$GID -R /etc/letsencrypt
  else
    chown $UID -R /etc/letsencrypt
  fi
fi

echo "Renewal process finished for domain $domain"
exit 0;
