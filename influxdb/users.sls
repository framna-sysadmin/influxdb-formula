{%- from "influxdb/defaults.yaml.jinja2" import rawmap with context %}
{%- set influxdb = salt['grains.filter_by'](rawmap, grain='os_family', merge=salt['pillar.get']('influxdb')) %}

{%- if "user" in influxdb and "remote" not in influxdb %}
{%- for name,config in influxdb["user"].items() %}
influxdb_user_{{ name }}:
  influxdb_user.present:
    - name: {{ name }}
    - passwd: {{ config["password"] }}
{%- if "admin" in config %}
    - admin: {{ config["admin"] }}
{%- endif %}
{%- if "grants" in config %}
    - grants: {{ config["grants"] }}
{%- endif %}
{%- endfor %}
{%- endif %}

{%- if "user" in influxdb and "remote" in influxdb %}
{%- set base_url = "https://" ~ influxdb['remote']['host'] ~ ":" ~ influxdb['remote']['port'] %}
{%- for name,config in influxdb["user"].items() %}
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

{%- set orgID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/orgs' | jq -r '.orgs[0].id'") %}
{%- set id = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/users?name=" ~ name ~ "' | jq -r '.users[0].id'") %}
{%- if "admin" in config and config["admin"] == True %}
check_{{ name }}_admin_in_org:
  http.query:
    - name: '{{ base_url }}/api/v2/orgs/{{ orgID }}/owners'
    - status: 200
    - method: GET
    - match: '"{{ name }}"'
    - match_type: string
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

make_{{ name }}_admin_in_org:
  http.query:
    - name: '{{ base_url }}/api/v2/orgs/{{ orgID }}/owners'
    - status: 201
    - method: POST
    - data: '{"name": "{{ name }}", "id": "{{ id }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: check_{{ name }}_admin_in_org
{%- else %}
check_{{ name }}_member_in_org:
  http.query:
    - name: '{{ base_url }}/api/v2/orgs/{{ orgID }}/members'
    - status: 200
    - method: GET
    - match: '"{{ name }}"'
    - match_type: string
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

make_{{ name }}_member_in_org:
  http.query:
    - name: '{{ base_url }}/api/v2/orgs/{{ orgID }}/members'
    - status: 201
    - method: POST
    - data: '{"name": "{{ name }}", "id": "{{ id }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: check_{{ name }}_member_in_org
{%- endif %}


{%- if "password" in config %}
set_password_{{ name }}:
  http.query:
    - name: '{{ base_url }}/api/v2/users/{{ id }}/password'
    - status: 204
    - method: POST
    - data: '{"password": "{{ config["password"] }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
{%- endif %}

{%- if "grants" in config %}
{%- for bucket,access in config['grants'].items() %}
{%- set bucketID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/buckets?name=" ~ bucket ~ "' | jq -r '.buckets[0].id'") %}

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

{%- set token = '-'.join([name, access, bucket]) %}
{%- set all_permissions = [{
    'action': 'read',
    'resource': {
      'id': bucketID,
      'orgID': orgID,
      'type': "buckets"
    }
  },{
    'action': 'write',
    'resource': {
      'id': bucketID,
      'orgID': orgID,
      'type': "buckets"
    }
  }] %}
{%- set base_permissions = [{
    'action': access,
    'resource': {
      'id': bucketID,
      'orgID': orgID,
      'type': "buckets"
    }
  }] %}
{%- set auth_data = {
  'token': token,
  'description': 'Grant ' ~ name ~ ' ' ~ access ~ ' access to bucket ' ~ bucket,
  'orgID': orgID,
  'userID': id,
  'permissions': all_permissions if access == 'all' else base_permissions
} %}

check_auth_user_{{ name }}_to_{{ bucket }}:
  http.query:
    - name: '{{ base_url }}/private/legacy/authorizations?token={{ token }}'
    - status: 200
    - method: GET
    - match: '"{{ token }}"'
    - match_type: string
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

auth_user_{{ name }}_to_{{ bucket }}:
  http.query:
    - name: '{{ base_url }}/private/legacy/authorizations'
    - status: 201
    - method: POST
    - data: '{{ auth_data | tojson }}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: check_auth_user_{{ name }}_to_{{ bucket }}

{%- set authID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/private/legacy/authorizations?token=" ~ token ~ "' | jq -r '.authorizations[0].id'") %}
password_auth_user_{{ name }}_to_{{ bucket }}:
  http.query:
    - name: '{{ base_url }}/private/legacy/authorizations/{{ authID }}/password'
    - status: 204
    - method: POST
    - data: '{"password": "{{ config["password"] }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

{%- endfor %}
{%- endif %}

{%- endfor %}
{%- endif %}