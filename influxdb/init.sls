# influxdb
#
# Meta-state to fully install influxdb.

include:
  - influxdb.pkgrepo
  - influxdb.install
  - influxdb.config
  - influxdb.service
  - influxdb.users

extend:
  influxdb_service:
    service:
      - watch:
        - file: influxdb_config
      - require:
        - file: influxdb_config
  influxdb_config:
    file:
      - require:
        - pkg: influxdb_install


