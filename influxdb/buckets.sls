{%- from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('influxdb')) %}

jq:
  pkg.installed

{%- if "bucket" in influxdb %}
{%- for config in influxdb["bucket"] %}
influxdb_bucket_{{ config['name'] }}:
  cmd.run:
    - name: >
        influx bucket create  --name "{{ config['name'] }}" \
                              --description "{{ config['description'] | default('A bucket') }}" \
                              --retention "{{ config['retention_policy'] | default(0) }}" \
                              --schema-type {{ config['type'] | default('implicit') }}
    - unless: influx bucket list --json | jq -e '.[] | select(.name == "{{ config['name'] }}")'
    - require:
      - pkg: jq

{%- set bucket = salt['cmd.shell']("influx bucket list --json | jq -r '.[] | select(.name == \"" + config['name'] + "\").id'") %}

{%- if 'mapping' in config and bucket %}
{%- for dbrp_config in config['mapping'] %}
{# can't use JQ since the output is two separated JSON objects #}
influxdb_bucket_{{ config['name'] }}_mapping_{{ dbrp_config['db'] }}/{{ dbrp_config['rp'] }}:
  cmd.run:
    - name: >
        influx v1 dbrp create --bucket-id "{{ bucket }}" \
                              --db "{{ dbrp_config['db'] }}" \
                              --rp "{{ dbrp_config['rp'] | default('autogen') }}"
    - unless: influx v1 dbrp list --db "{{ dbrp_config['db'] }}" --rp "{{ dbrp_config['rp'] }}" | grep "{{ dbrp_config['db'] }}"
    - require:
      - cmd: influxdb_bucket_{{ config['name'] }}
{%- endfor %}
{%- endif %}
{%- endfor %}
{%- endif %}
