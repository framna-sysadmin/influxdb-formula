# influxdb
#
# Meta-state to fully install influxdb.

include:
  - influxdb.pkgrepo
  - influxdb.install
  - influxdb.initial_config
  - influxdb.service
  - influxdb.users
  - influxdb.config

{% from "influxdb/defaults.yaml" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

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
{% if "user" in influxdb %}
{% for name,config in influxdb["user"].items() %}
  influxdb_user_{{ loop.index0 }}:
    influxdb_user:
      - require:
        - file: influxdb_initial_config
        - service: influxdb_service
      - require_in:
        - file: influxdb_config
{% endfor %}
{% endif %}
