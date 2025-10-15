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

{%- set orgID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/orgs' | jq -r '.orgs[0].id'") %} # noqa: 204
{%- set id = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/users?name=" ~ name ~ "' | jq -r '.users[0].id'") %} # noqa: 204
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
{%- set permissions = [] %}
{%- for bucket,access in config['grants'].items() %}
{%- set bucketID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/api/v2/buckets?name=" ~ bucket ~ "' | jq -r '.buckets[0].id'") %} # noqa: 204

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

{%- if access == 'all' %}
  {%- set _ = permissions.append({
      'action': 'read',
      'resource': {
        'id': bucketID,
        'orgID': orgID,
        'type': "buckets"
      }
    })
  %}
  {%- set _ = permissions.append({
      'action': 'write',
      'resource': {
        'id': bucketID,
        'orgID': orgID,
        'type': "buckets"
      }
    })
  %}
{%- else %}
  {%- set _ = permissions.append({
      'action': access,
      'resource': {
        'id': bucketID,
        'orgID': orgID,
        'type': "buckets"
      }
    })
  %}
{%- endif %}
{%- endfor %}

{%- set legacy_auth_data = {
  'token': name ~ '-legacy',
  'description': 'Grant ' ~ name ~ ' legacy access to buckets',
  'orgID': orgID,
  'userID': id,
  'permissions': permissions
} %}

check_auth_user_{{ name }}_legacy:
  http.query:
    - name: '{{ base_url }}/private/legacy/authorizations?token={{ name }}-legacy'
    - status: 200
    - method: GET
    - match: '"{{ legacy_auth_data.token }}"'
    - match_type: string
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

auth_user_{{ name }}_legacy:
  http.query:
    - name: '{{ base_url }}/private/legacy/authorizations'
    - status: 201
    - method: POST
    - data: '{{ legacy_auth_data | tojson }}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: check_auth_user_{{ name }}_legacy

{%- set authID = salt['cmd.shell']("curl -s -f -H'Authorization: Token " ~ influxdb['user']['admin']['token'] ~ "' '" ~ base_url ~ "/private/legacy/authorizations?token=" ~ legacy_auth_data.token ~ "' | jq -r '.authorizations[0].id'") %} # noqa: 204
password_auth_user_{{ name }}_legacy:
  http.query:
    - name: '{{ base_url }}/private/legacy/authorizations/{{ authID }}/password'
    - status: 204
    - method: POST
    - data: '{"password": "{{ config["password"] }}"}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

{%- set auth_data = {
  'token': name,
  'description': 'Grant ' ~ name ~ ' access to buckets',
  'orgID': orgID,
  'userID': id,
  'permissions': permissions
} %}
check_auth_user_{{ name }}_v2:
  http.query:
    - name: '{{ base_url }}/api/v2/authorizations?user={{ name }}'
    - status: 200
    - method: GET
    - match: '"{{ auth_data.token }}"'
    - match_type: string
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}

auth_user_{{ name }}_v2:
  http.query:
    - name: '{{ base_url }}/api/v2/authorizations'
    - status: 201
    - method: POST
    - data: '{{ auth_data | tojson }}'
    - header_dict:
        Authorization: Token {{ influxdb['user']['admin']['token'] }}
    - onfail:
        - http: check_auth_user_{{ name }}_v2
{%- endif %}

{%- endfor %}
{%- endif %}