{% from "influxdb/map.jinja" import influxdb_settings with context %}

include:
  - influxdb.install

influxdb_start:
  service.running:
    - name: influxdb
    - enable: True
    - watch:
      - pkg: influxdb_install
    - require:
      - pkg: influxdb_install
