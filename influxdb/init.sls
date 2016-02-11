{% from "influxdb/map.jinja" import influxdb_settings with context %}

influxdb_install:
  pkg.installed:
    - name: influxdb
