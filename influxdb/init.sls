# influxdb
#
# Meta-state to fully install influxdb.
{% from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

include:
{% if "remote" not in influxdb %}
  - influxdb.pkgrepo
  - influxdb.install
  - influxdb.initial_config
  - influxdb.service
{% endif %}
  - influxdb.databases
  - influxdb.users
{% if "remote" not in influxdb %}
  - influxdb.config
{% endif %}

{% if "remote" not in influxdb %}
influxdb_wait:
  module.run:
    - name: test.sleep
    - length: 10
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
{% endif %}