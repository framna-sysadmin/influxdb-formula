include:
  - influxdb.install

influxdb_service:
  service.running:
    - name: influxdb
    - enable: True
    - watch:
      - pkg: influxdb_install
    - require:
      - pkg: influxdb_install
