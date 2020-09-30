#!/bin/sh

echo "[*] Starting bunkerized-php ..."

# execute custom scripts if it's a customized image
for file in /entrypoint.d/* ; do
    [ -f "$file" ] && [ -x "$file" ] && "$file"
done

# trap SIGTERM and SIGINT
function trap_exit() {
	echo "[*] Stopping crond ..."
	pkill -TERM crond
	echo "[*] Stopping php ..."
	pkill -TERM php-fpm7
	echo "[*] Stopping syslogd ..."
	pkill -TERM syslogd
	pkill -TERM tail
}
trap "trap_exit" TERM INT

# replace pattern in file
function replace_in_file() {
	# escape slashes
	pattern=$(echo "$2" | sed "s/\//\\\\\//g")
	replace=$(echo "$3" | sed "s/\//\\\\\//g")
	sed -i "s/$pattern/$replace/g" "$1"
}

# copy stub confs
cp /opt/confs/php.ini /etc/php7/php.ini
cp /opt/confs/syslog.conf /etc/syslog.conf
cp /opt/confs/logrotate.conf /etc/logrotate.conf
cp /opt/confs/snuffleupagus.rules /etc/php7/conf.d/snuffleupagus.rules

# remove cron jobs
echo "" > /etc/crontabs/root

# set default values
PHP_DOC_ROOT="${ROOT_FOLDER-/www}"
PHP_EXPOSE="${PHP_EXPOSE-0}"
PHP_DISPLAY_ERRORS="${PHP_DISPLAY_ERRORS-0}"
PHP_OPEN_BASEDIR="${PHP_OPEN_BASEDIR-/www/:/tmp/uploads/:/tmp/sessions/}"
PHP_ALLOW_URL_FOPEN="${PHP_ALLOW_URL_FOPEN-0}"
PHP_ALLOW_URL_INCLUDE="${PHP_ALLOW_URL_INCLUDE-0}"
PHP_FILE_UPLOADS="${PHP_FILE_UPLOADS-0}"
PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE-10M}"
PHP_UPLOAD_TMP_DIR="${PHP_UPLOAD_TMP_DIR-/tmp/uploads}"
PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE-10M}"
PHP_DISABLE_FUNCTIONS="${PHP_DISABLE_FUNCTIONS-system, exec, shell_exec, passthru, phpinfo, show_source, highlight_file, popen, proc_open, fopen_with_path, dbmopen, dbase_open, putenv, filepro, filepro_rowcount, filepro_retrieve, posix_mkfifo}"
PHP_SESSION_SAVE_PATH="${PHP_SESSION_SAVE_PATH-/tmp/sessions}"
PHP_SESSION_COOKIE_SECURE="${PHP_SESSION_COOKIE_SECURE-0}"
PHP_SESSION_COOKIE_PATH="${PHP_SESSION_COOKIE_PATH-/}"
PHP_SESSION_COOKIE_HTTPONLY="${PHP_SESSION_COOKIE_HTTPONLY-1}"
PHP_SESSION_COOKIE_SAMESITE="${PHP_SESSION_COOKIE_SAMESITE-Strict}"
PHP_SESSION_NAME="${PHP_SESSION_NAME-random}"
# session.cookie_domain = %PHP_SESSION_COOKIE_DOMAIN%
USE_SNUFFLEUPAGUS="{USE_SNUFFLEUPAGUS-yes}"
LOGROTATE_MINSIZE="${LOGROTATE_MINSIZE-10M}"
LOGROTATE_MAXAGE="${LOGROTATE_MAXAGE-7}"

# install additional modules if needed
if [ "$ADDITIONAL_MODULES" != "" ] ; then
	apk add $ADDITIONAL_MODULES
fi

# replace values
replace_in_file "/etc/php7/php.ini" "%PHP_EXPOSE%" "$PHP_EXPOSE"
replace_in_file "/etc/php7/php.ini" "%PHP_DISPLAY_ERRORS%" "$PHP_DISPLAY_ERRORS"
replace_in_file "/etc/php7/php.ini" "%PHP_OPEN_BASEDIR%" "$PHP_OPEN_BASEDIR"
replace_in_file "/etc/php7/php.ini" "%PHP_ALLOW_URL_FOPEN%" "$PHP_ALLOW_URL_FOPEN"
replace_in_file "/etc/php7/php.ini" "%PHP_ALLOW_URL_INCLUDE%" "$PHP_ALLOW_URL_INCLUDE"
replace_in_file "/etc/php7/php.ini" "%PHP_FILE_UPLOADS%" "$PHP_FILE_UPLOADS"
replace_in_file "/etc/php7/php.ini" "%PHP_UPLOAD_MAX_FILESIZE%" "$PHP_UPLOAD_MAX_FILESIZE"
replace_in_file "/etc/php7/php.ini" "%PHP_UPLOAD_TMP_DIR%" "$PHP_UPLOAD_TMP_DIR"
replace_in_file "/etc/php7/php.ini" "%PHP_DISABLE_FUNCTIONS%" "$PHP_DISABLE_FUNCTIONS"
replace_in_file "/etc/php7/php.ini" "%PHP_POST_MAX_SIZE%" "$PHP_POST_MAX_SIZE"
replace_in_file "/etc/php7/php.ini" "%PHP_DOC_ROOT%" "$PHP_DOC_ROOT"
replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_SAVE_PATH%" "$PHP_SESSION_SAVE_PATH"
replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_COOKIE_SECURE%" "$PHP_SESSION_COOKIE_SECURE"
replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_COOKIE_PATH%" "$PHP_SESSION_COOKIE_PATH"
replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_COOKIE_HTTPONLY%" "$PHP_SESSION_COOKIE_HTTPONLY"
replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_COOKIE_SAMESITE%" "$PHP_SESSION_COOKIE_SAMESITE"
replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_COOKIE_DOMAIN%" "$PHP_SESSION_COOKIE_DOMAIN"
if [ "$PHP_SESSION_NAME" = "random" ] ; then
	rand_nb=$((10 + RANDOM % 11))
	rand_name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $rand_nb | head -n 1)
	replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_NAME%" "$rand_name"
else
	replace_in_file "/etc/php7/php.ini" "%PHP_SESSION_NAME%" "$PHP_SESSION_NAME"
fi

# snuffleupagus setup
if [ "$USE_SNUFFLEUPAGUS" = "yes" ] ; then
	replace_in_file "/etc/php7/php.ini" "%SNUFFLEUPAGUS_EXTENSION%" "extension=snuffleupagus.so"
	if [ -f "/snuffleupagus.rules" ] ; then
		replace_in_file "/etc/php7/php.ini" "%SNUFFLEUPAGUS_CONFIG%" "sp.configuration_file=/snuffleupagus.rules"
	else
		replace_in_file "/etc/php7/php.ini" "%SNUFFLEUPAGUS_CONFIG%" "sp.configuration_file=/etc/php7/conf.d/snuffleupagus.rules"
	fi
else
	replace_in_file "/etc/php7/php.ini" "%SNUFFLEUPAGUS_EXTENSION%" ""
	replace_in_file "/etc/php7/php.ini" "%SNUFFLEUPAGUS_CONFIG%" ""
fi

# start syslogd
syslogd -S

# setup logrotate
replace_in_file "/etc/logrotate.conf" "%LOGROTATE_MAXAGE%" "$LOGROTATE_MAXAGE"
replace_in_file "/etc/logrotate.conf" "%LOGROTATE_MINSIZE%" "$LOGROTATE_MINSIZE"
echo "0 0 * * * logrotate -f /etc/logrotate.conf > /dev/null 2>&1" >> /etc/crontabs/root

# start crond
crond

# start PHP
replace_in_file "/etc/php7/php-fpm.d/www.conf" "user = nobody" "user = php"
replace_in_file "/etc/php7/php-fpm.d/www.conf" "group = nobody" "group = php"
PHP_INI_SCAN_DIR=:/php.d/ php-fpm7
if [ ! -f "/var/log/php-fpm.log" ] ; then
	touch /var/log/php-fpm.log
fi
if [ ! -f "/var/log/php.log" ] ; then
	touch /var/log/php.log
fi
tail -f /var/log/php-fpm.log /var/log/php.log &
wait $!

# sigterm trapped
echo "[*] bunkerized-php stopped"
exit 0
