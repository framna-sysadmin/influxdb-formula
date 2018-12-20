# influxdb
#
# Meta-state to fully install influxdb.

include:
  - influxdb.pkgrepo
  - influxdb.install
  - influxdb.initial_config
  - influxdb.service
  - influxdb.databases
  - influxdb.users
  - influxdb.config

{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

influxdb_wait:
  module.run:
    - name: test.sleep
    - length: 5
    - require:
      - service: influxdb_service

influxdb_reload:
  service.running:
    - name: influxdb
    - require:
      - file: influxdb_config
    - watch:
      - file: influxdb_config

extend:
  influxdb_service:
    service:
      - watch:
        - file: influxdb_initial_config
      - require:
        - file: influxdb_initial_config
  influxdb_initial_config:
    file:
      - require:
        - pkg: influxdb_install
{% if "database" in influxdb %}
{% for config in influxdb["database"] %}
  influxdb_database_{{ config['name'] }}:
    influxdb_database:
      - require:
        - file: influxdb_initial_config
        - module: influxdb_wait
      - require_in:
        - file: influxdb_config
{% endfor %}
{% endif %}
{% if "user" in influxdb %}
{% for name,config in influxdb["user"].items() %}
  influxdb_user_{{ loop.index0 }}:
    influxdb_user:
      - require:
        - file: influxdb_initial_config
        - module: influxdb_wait
{% if "database" in influxdb %}
{% for config in influxdb["database"] %}
        - influxdb_database: influxdb_database_{{ config['name'] }}
{% endfor %}
{% endif %}
      - require_in:
        - file: influxdb_config
{% endfor %}
{% endif %}
