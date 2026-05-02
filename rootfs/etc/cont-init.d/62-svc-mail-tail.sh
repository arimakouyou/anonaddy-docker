#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# Postfix が /var/log/mail.log にログを書くため、Docker logs / journald 経路を維持する目的で
# tail -F の出力をコンテナ stdout に流す s6 service を登録する。
set -e

mkdir -p /etc/services.d/mail-tail
cat >/etc/services.d/mail-tail/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
tail -F -n 0 /var/log/mail.log
EOL
chmod +x /etc/services.d/mail-tail/run
