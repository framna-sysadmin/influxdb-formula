{% from "influxdb/map.jinja" import influxdb_settings with context %}

influxdb_config:
  file.managed:
    - name: {{ influxdb_settings.config }}
    - source: {{ influxdb_settings.tmpl.config }}
    - user: root
    - group: root
    - makedirs: True
    - dir_mode: 755
    - mode: 644
    - template: jinja

