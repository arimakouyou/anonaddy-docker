#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# Postfix maillog_file=/var/log/mail.log で動かすための準備:
#   - ファイルを作成し postfix に書き込み権、anonaddy に読み取り権を付与
#   - rotate 後に default ACL が継承されるよう setfacl -d も適用
set -e

MAIL_LOG=/var/log/mail.log
mkdir -p "$(dirname "$MAIL_LOG")"
[ -f "$MAIL_LOG" ] || install -m 0640 -o postfix -g postfix /dev/null "$MAIL_LOG"
chown postfix:postfix "$MAIL_LOG"
chmod 0640 "$MAIL_LOG"
setfacl -m u:anonaddy:r "$MAIL_LOG"
setfacl -d -m u:anonaddy:r "$(dirname "$MAIL_LOG")" 2>/dev/null || true
