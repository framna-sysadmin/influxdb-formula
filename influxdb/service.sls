{% from "influxdb/map.jinja" import influxdb_settings with context %}

influxdb_start:
  service.running:
    - name: {{ influxdb_settings.service }}
    - enable: True
    - watch:
      - pkg: influxdb_install
      - file: influxdb_config
    - require:
      - pkg: influxdb_install
      - file: influxdb_config
