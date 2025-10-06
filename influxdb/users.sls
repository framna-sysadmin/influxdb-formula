{% from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

{% if "user" in influxdb and "remote" not in influxdb %}
{% for name,config in influxdb["user"].items() %}
influxdb_user_{{ name }}:
  influxdb_user.present:
    - name: {{ name }}
    - passwd: {{ config["password"] }}
{% if "admin" in config %}
    - admin: {{ config["admin"] }}
{% endif %}
{% if "grants" in config %}
    - grants: {{ config["grants"] }}
{% endif %}
{% endfor %}
{% endif %}

{% if "user" in influxdb and "remote" in influxdb %}
{%- set base_url = "https://" ~ influxdb['remote']['host'] ~ ":" ~ influxdb['remote']['port'] %}
{% for name,config in influxdb["user"].items() %}
get_user_{{ name }}:
  http.query:
    - name: '{{ base_url }}/api/v2/users/?name={{ name }}'
    - status: 200
    - method: GET
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

create_user_{{ name }}:
  http.query:
    - name: '{{ base_url }}/api/v2/users'
    - status: 201
    - method: POST
    - data: '{"name": "{{ name }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: get_user_{{ name }}

{%- set id = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/users?name=" ~ name ~ "' | jq -r '.users[0].id'") %}
{% if "password" in config %}
set_password_{{ name }}:
  http.query:
    - name: '{{ base_url }}/api/v2/users/{{ id }}/password'
    - status: 204
    - method: POST
    - data: '{"password": "{{ config["password"] }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
{% endif %}

{% if "grants" in config %}
{%- for bucket,access in config['grants'].items() %}
{%- set bucketID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/buckets' | jq -r '.buckets[] | select(.name == \"" + bucket + "\").id'") %}
check_grant_user_{{ name }}_to_{{ bucket }}:
  http.query:
    - name: '{{ base_url }}/api/v2/buckets/{{ bucketID }}/members'
    - status: 200
    - method: GET
    - match: '"{{ name }}"'
    - match_type: string
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

grant_user_{{ name }}_to_{{ bucket }}:
  http.query:
    - name: '{{ base_url }}/api/v2/buckets/{{ bucketID }}/members'
    - status: 201
    - method: POST
    - data: '{"name": "{{ name }}", "id": "{{ id }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: check_grant_user_{{ name }}_to_{{ bucket }}
{%- endfor %}
{% endif %}

{% endfor %}
{% endif %}