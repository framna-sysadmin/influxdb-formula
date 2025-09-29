{% from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

{% if "user" in influxdb and "remote" not in influxdb %}
{% for name,config in influxdb["user"].items() %}
influxdb_user_{{ loop.index0 }}:
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
{% for name,config in influxdb["user"].items() %}
get_user_{{ loop.index0 }}:
  http.query:
    - name: 'https://{{ influxdb['remote']['host'] }}/api/v2/users/{{ name }}'
    - status: 200
    - method: GET
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

create_user_{{ loop.index0 }}:
  http.query:
    - name: 'https://{{ influxdb['remote']['host'] }}/api/v2/users'
    - status: 200
    - method: POST
    - data: '{"name": "{{ name }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: get_user_{{ loop.index0 }}

{% if "password" in config %}
set_password_{{ loop.index0 }}:
  http.query:
    - name: 'https://{{ influxdb['remote']['host'] }}/api/v2/users{{ name }}/password'
    - status: 200
    - method: POST
    - data: '{"password": "{{ config["password"] }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
{% endif %}

{% endfor %}
{% endif %}