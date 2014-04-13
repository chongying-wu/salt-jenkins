{% from '_python.sls' import python with context %}
{% set git_url =  pillar.get('git_url', 'https://github.com/saltstack/salt-bootstrap.git') %}
{% set svi = salt['config.get']('virtualenv_path', '/SaViEn') %}

include:
  - git
  - python.virtualenv
  - python.pyyaml
  - python.jinja2
  - python.m2crypto
  - python.pycrypto
  - python.pyzmq
  - python.salttesting
  - python.supervisor
  - python.libcloud
  - python.msgpack
  {%- if grains.get('pythonversion')[:2] < [2, 7] %}
  - python.unittest2
  {%- endif %}
  {%- if grains['os'] == 'openSUSE' %}
  {#- Yes! openSuse ships xml as separate package #}
  - python.xml
  {%- endif %}
  - python.mock
  - python.unittest-xml-reporting

{{ svi }}:
  virtualenv.managed:
    - python: {{ python }}
    - order: 1
    - require:
      - pip: virtualenv

{{ svi }}/etc:
  file.directory:
    - require:
      - virtualenv: {{ svi }}

copy-salt-config:
  cmd.run:
    - name: cp -Rp /etc/salt {{ svi }}/etc/
    - require:
      - virtualenv: {{ svi }}

{{ svi }}/etc/supervisor.d/salt.ini:
  file.managed:
    - source: salt://supervisor/salt.ini
    - makedirs: true
    - template: jinja
    - require:
      - virtualenv: {{ svi }}

{{ svi }}/log/supervisor:
  file.directory:
    - makedirs: true
    - require:
      - virtualenv: {{ svi }}

{{ svi }}/var/cache:
  file.directory:
    - makedirs: true
    - require:
      - virtualenv: {{ svi }}

{{ svi }}/var/run/salt:
  file.directory:
    - makedirs: true
    - require:
      - virtualenv: {{ svi }}

{{ svi }}/srv/salt:
  file.directory:
    - makedirs: true
    - require:
      - virtualenv: {{ svi }}

{{ svi }}/srv/pillar:
  file.directory:
    - makedirs: true
    - require:
      - virtualenv: {{ svi }}

adapt-/etc/salt/:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: /etc/salt
    - repl: {{ svi }}/etc/salt
    - require:
      - cmd: copy-salt-config

adapt-/var/run:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: /var/run
    - repl: {{ svi }}/var/run
    - require:
      - cmd: copy-salt-config

adapt-/var/cache:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: /var/cache/salt
    - repl: {{ svi }}/var/cache
    - require:
      - cmd: copy-salt-config

adapt_conf_file:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: 'conf_file: /etc/salt/minion'
    - repl: 'conf_file: {{ svi }}/etc/salt/minion'
    - require:
      - cmd: copy-salt-config

adapt-/srv/salt:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: /srv/salt
    - repl: {{ svi }}/srv/salt
    - require:
      - cmd: copy-salt-config

adapt-/srv/pillar:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: /srv/salt
    - repl: {{ svi }}/srv/pillar
    - require:
      - cmd: copy-salt-config

adapt-/var/log:
  file.replace:
    - name: {{ svi }}/etc/salt/minion
    - pattern: /var/log/salt
    - repl: {{ svi }}/log
    - require:
      - cmd: copy-salt-config

install-salt:
  pip.installed:
    - name: salt
    - bin_env: {{ svi }}
    - install_options:
      - --salt-config-dir={{ svi }}/etc/salt
      - --salt-cache-dir={{ svi }}/cache
      - --salt-sock-dir={{ svi }}/run/salt
      - --salt-srv-root-dir={{ svi }}/srv
      - --salt-base-file-roots-dir={{ svi }}/salt
      - --salt-base-pillar-roots-dir={{ svi }}/pillar
      - --salt-logs-dir={{ svi }}/log
      - --salt-pidfile-dir={{ svi }}/run
    - require:
      - file: adapt-/var/log
      - virtualenv: {{ svi }}
      {%- if grains['os'] == 'openSUSE' %}
      {#- Yes! openSuse ships xml as separate package #}
      - pkg: python-xml
      {%- endif %}
      - pip: SaltTesting
      {%- if grains.get('pythonversion')[:2] < [2, 7] %}
      - pip: unittest2
      {%- endif %}
      - pip: mock
      - pip: unittest-xml-reporting
      - pip: jinja2
      - pip: PyYAML
      - pip: m2crypto
      - pip: pycrypto
      - pip: pyzmq
      - pip: apache-libcloud
      - pip: msgpack-python


start-supervisord:
  cmd.run:
    - name: {{ svi }}/bin/supervisord -c {{ svi }}/etc/supervisor.d/salt.ini
    - require:
      - pip: supervisor
      - file: {{ svi }}/etc/supervisor.d/salt.ini

run-salt:
  supervisord:
    - running
    - name: salt
    - bin_env: {{ svi }}/bin/supervisorctl
    - conf_file: {{ svi }}/etc/supervisor.d/salt.ini
    - require:
      - pip: install-salt
      - cmd: start-supervisord

{# Setup Salt Bootstrap Source #}
/testing:
  file.directory

{{git_url}}:
  git.latest:
    - name: {{ git_url }}
    - rev: {{ pillar.get('git_commit', 'develop') }}
    - target: /testing
    - require:
      - file: /testing
      - pkg: git
      - supervisord: run-salt
