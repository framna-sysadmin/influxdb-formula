{% set name = {
    'RedHat': 'redhat',
    'Debian': 'debian',
}.get(grains.os_family) %}
include:
  - .{{ name }}.absent