{%- from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

jq:
  pkg.installed

{% if "remote" in influxdb %}
{%- set base_url = "https://" ~ influxdb['remote']['host'] ~ ":" ~ influxdb['remote']['port'] %}
{% endif %}

{%- if "bucket" in influxdb %}
{%- for config in influxdb["bucket"] %}
{% if "remote" not in influxdb %}
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
{% else %}
{%- set orgID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/orgs' | jq -r '.orgs[0].id'") %}

get_bucket_{{ config['name'] }}:
  http.query:
    - name: '{{ base_url }}/api/v2/buckets?orgId={{ orgID }}&name={{ config['name'] }}'
    - match: '"{{ config.name }}"'
    - match_type: string
    - status: 200
    - method: GET
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

{%- set bucket_data = {
  'name':           config['name'],
  'description':    config['description'] | default('A bucket for ' + config['name']),
  'orgID':          orgID,
  'rp':             config['retention_policy'] | default('0'),
} %}
create_bucket_{{ config['name'] }}:
  http.query:
    - name: '{{ base_url }}/api/v2/buckets'
    - status: 201
    - method: POST
    - data: '{{ bucket_data | tojson }}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: get_bucket_{{ config['name'] }}
{%- set bucket = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/buckets?name=" ~ config['name'] ~ "' | jq -r '.buckets[0].id'") %}
{% endif %}

{%- if 'mapping' in config and bucket %}
{%- for dbrp_config in config['mapping'] %}
{# can't use JQ since the output is two separated JSON objects #}
{% if "remote" not in influxdb %}
{% if dbrp_config['default'] == true %}
{%- set dbrp_default = "--default" %}
{% else %}
{%- set dbrp_default = "" %}
{% endif %}
influxdb_bucket_{{ config['name'] }}_mapping_{{ dbrp_config['db'] }}/{{ dbrp_config['rp'] }}:
  cmd.run:
    - name: >
        influx v1 dbrp create --bucket-id "{{ bucket }}" \
                              --db "{{ dbrp_config['db'] }}" \
                              --rp "{{ dbrp_config['rp'] | default('autogen') }}" \
                              {{ dbrp_default }}
    - unless: influx v1 dbrp list --db "{{ dbrp_config['db'] }}" --rp "{{ dbrp_config['rp'] }}" | grep "{{ dbrp_config['db'] }}"
    - require:
      - cmd: influxdb_bucket_{{ config['name'] }}
{%- else %}
get_bucket_{{ config['name'] }}_mapping_{{ dbrp_config['db'] }}/{{ dbrp_config['rp'] }}:
  http.query:
    - name: '{{ base_url }}/api/v2/dbrps?orgID={{ orgID }}&bucketID={{ bucket }}&db={{ dbrp_config['db'] }}&rp={{ dbrp_config['rp'] }}'
    - match: '"{{ dbrp_config.rp }}"'
    - match_type: string
    - status: 200
    - method: GET
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

{%- set dbrp_data = {
  'bucketID':         bucket,
  'database':         dbrp_config['db'],
  'retention_policy': dbrp_config['rp'] | default('autogen'),
  'default':          dbrp_config['default'],
  'orgID':            orgID,
} %}
create_bucket_{{ config['name'] }}_mapping_{{ dbrp_config['db'] }}/{{ dbrp_config['rp'] }}:
  http.query:
    - name: '{{ base_url }}/api/v2/dbrps'
    - status: 201
    - method: POST
    - data: '{{ dbrp_data | tojson }}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: get_bucket_{{ config['name'] }}_mapping_{{ dbrp_config['db'] }}/{{ dbrp_config['rp'] }}
{%- endif %}
{%- endfor %}
{%- endif %}
{%- endfor %}
{%- endif %}
