{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

{% if 'backup' in influxdb %}
influxdb-script-backup:
  file.managed:
    - name: /usr/local/bin/influxdb_backup
    - user: root
    - group: root
    - mode: 755
    - source: salt://influxdb/files/backup.sh
    - template: jinja
    - defaults:
        config: {{ influxdb.backup }}

influxdb-script-backup-logdir:
  file.directory:
    - name: {{ influxdb.backup.log_dir }}
    - user: root
    - group: root
    - mode: 755

influxdb-script-backup-cronjob:
  cron.present:
    - name: /usr/local/bin/influxdb_backup &>> {{ influxdb.backup.log_dir }}/influxdb.log
    - identifier: influxdb_backup
    - special: '@daily'
{% endif %}
