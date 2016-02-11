drop-influxdata-pkgrepo:
  pkgrepo.absent:
    - name: deb http://debian.saltstack.com/debian {{ grains['oscodename'] }} stable
  file.absent:
    - name: /etc/apt/sources.list.d/influxdata.list

drop-influxdata-apt-key:
  file.absent:
    - name: /etc/apt/trusted.gpg.d/influxdata.gpg
