#!/bin/bash
START_TIME=$(date +"%s")
S3_DIR="{{ config.s3_dir }}"
TARGET_DIR="{{ config.target_dir }}"

DATE_TODAY=$(date --rfc-3339=date)
DATE_LASTWEEK=$(date -d "-7 days" --rfc-3339=date)

function report() {
  TYPE=$1
  BACKUP_PATH=$2
  STATUS_CODE=$3
  END_TIME=$(date +"%s")
  TIME=$(expr $END_TIME - $START_TIME)
  if [ "$TYPE" = "unknown" ]; then
    SIZE=0
  else
    SIZE=$(du -sb $BACKUP_PATH | grep -o '[0-9]*' | head -1)
  fi
  if [ -z "$SIZE" ]; then
    SIZE=0
  fi
{%- if 'influxdb' in config %}
  {% set comma = joiner(",") -%}
  TAGS="{% for key,item in config.influxdb.tags.items() -%}
  {{comma()}}{{ key }}={{ item }}
  {%- endfor %}"
  curl -i -XPOST -u '{{ config.influxdb.user }}:{{ config.influxdb.password }}' 'http://{{ config.influxdb.host }}:8086/write?db={{ config.influxdb.database }}' \
    --data-binary "backup,$TAGS,application=influxdb,status=$3,type=$1 size=${SIZE}i,duration=${TIME}i"
{%- endif %}
}

if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR"
fi

if [ ! -d "$TARGET_DIR/base" ]; then
  echo "No base backup exists."
  mkdir -p "$TARGET_DIR/base"
  influxd backup -portable "$TARGET_DIR/base"
  STATUS=$?
  report "initial" "$TARGET_DIR/base" $STATUS
else
  if [ $(date -d "-6 days" +%s) -ge $(date -r "$TARGET_DIR/base" +%s) ]; then
    if [ -e "$TARGET_DIR/base_new" ]; then
      # if we use S3 remount it, just to be sure it didn't get stuck
      if ! [ -z "$S3_DIR" ]; then
        umount "$S3_DIR"
        mount "$S3_DIR"
      fi

      # cleanup incomplete full backup
      rm -rf "$TARGET_DIR/base_new"
    fi

    influxd backup -portable "$TARGET_DIR/base_new"
    STATUS=$?

    if [ $STATUS = 0 ]; then
      DATESTRING=$DATE_LASTWEEK

      mkdir -p "$TARGET_DIR/backup-$DATESTRING"
      mv "$TARGET_DIR/base" "$TARGET_DIR/backup-$DATESTRING/base" || STATUS=2
      mv "$TARGET_DIR/base_new" "$TARGET_DIR/base" || STATUS=3
      mv "$TARGET_DIR/inc-"* "$TARGET_DIR/backup-$DATESTRING/" || STATUS=4
    fi

    report "full" "$TARGET_DIR/base" $STATUS
    exit 0
  fi

  influxd backup -portable -start $(date -u -d "yesterday 00:00" "+%Y-%m-%dT%H:%M:%SZ") "$TARGET_DIR/inc-$DATE_TODAY"
  STATUS=$?
  report "incremental" "$TARGET_DIR/inc-$DATE_TODAY" $STATUS
fi
