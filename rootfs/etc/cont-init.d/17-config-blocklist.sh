#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# anonaddy v1.4 以降の blocklist 機能用 Rspamd Lua プラグインを配備する。
# ADDY_BLOCKLIST_ENABLE=true の時のみ有効化。
set -e

. "$(dirname "$0")/00-env"

LUA_DIR=/etc/rspamd/lua.local.d
LUA_FILE="${LUA_DIR}/addy_blocklist.lua"

if [ "${ADDY_BLOCKLIST_ENABLE}" != "true" ]; then
  rm -f "$LUA_FILE"
  exit 0
fi

if [ "${RSPAMD_ENABLE}" != "true" ]; then
  echo "WRN: ADDY_BLOCKLIST_ENABLE=true だが RSPAMD_ENABLE が true ではないため Lua プラグインを配備しません。"
  exit 0
fi

mkdir -p "$LUA_DIR"
cat >"$LUA_FILE" <<'EOL'
--[[
  Rspamd Lua script: anonaddy/addy.io blocklist check via Laravel HTTP API.
  詳細: https://github.com/anonaddy/anonaddy releases v1.4.0
  - blocklist_api_url / blocklist_secret は cont-init.d/17-config-blocklist.sh が
    環境変数から sed で書き換える。
--]]
local blocklist_api_url = '__BLOCKLIST_API_URL__'
local blocklist_secret = '__BLOCKLIST_SECRET__'

local function url_encode(s)
  if s == nil or s == '' then return '' end
  s = tostring(s)
  return (s:gsub('[^%w%-_.~ ]', function(c)
    return string.format('%%%02X', string.byte(c))
  end):gsub(' ', '%%20'))
end

local logger = require "rspamd_logger"
local rspamd_http = require 'rspamd_http'

rspamd_config:register_symbol({
  name = 'BLOCKLIST_USER',
  callback = function(task)
    local rcpts = task:get_recipients('smtp')
    local from_env = task:get_from('smtp')
    if not rcpts or #rcpts == 0 then
      logger.infox('blocklist: skip - missing recipient')
      return false
    end
    local recipient = (rcpts[1].addr and rcpts[1].addr:lower()) or ''

    local sender = ''
    if from_env and #from_env > 0 and from_env[1].addr then
      sender = from_env[1].addr:lower()
    end

    local query = 'recipient=' .. url_encode(recipient) .. '&sender=' .. url_encode(sender)
    local url = blocklist_api_url .. '?' .. query

    local headers = {}
    if blocklist_secret and blocklist_secret ~= '' then
      headers['X-Blocklist-Secret'] = blocklist_secret
    end

    local function http_callback(err, code, body)
      if err then
        logger.errx(task, 'blocklist HTTP error: %s', err)
        return
      end
      if code ~= 200 then
        logger.infox(task, 'blocklist HTTP non-200: %s', code)
        return
      end
      if body and string.find(body, '"block"%s*:%s*true') then
        task:insert_result('BLOCKLIST_USER', 1.0)
      end
    end

    rspamd_http.request({
      task = task,
      url = url,
      headers = headers,
      callback = http_callback,
      timeout = 4.0,
    })
    return true
  end,
})
EOL

# プレースホルダを実値に置換 (パスワード文字を含むため | 区切り)
sed -i "s|__BLOCKLIST_API_URL__|${ADDY_BLOCKLIST_API_URL}|" "$LUA_FILE"
sed -i "s|__BLOCKLIST_SECRET__|${BLOCKLIST_API_SECRET}|" "$LUA_FILE"

chown rspamd:rspamd "$LUA_FILE"
chmod 0640 "$LUA_FILE"
