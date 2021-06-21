{%- set distro = salt['grains.get']('oscodename', '')  %}
{%- set os_family = salt['grains.get']('os_family', '') %}
{%- set os_major_release = salt['grains.get']('osmajorrelease', 0)|int %}
{%- set os = salt['grains.get']('os', '') %}
{%- set get_pip_dir = salt.temp.dir(prefix='get-pip-') %}
{%- set get_pip_path = (get_pip_dir | path_join('get-pip.py')).replace('\\', '\\\\') %}

{%- if os_family == 'RedHat' and os_major_release == 6 %}
  {%- set on_redhat_6 = True %}
{%- else %}
  {%- set on_redhat_6 = False %}
{%- endif %}

{%- if os_family == 'RedHat' and os_major_release == 2018 %}
  {%- set on_amazonlinux_1 = True %}
{%- else %}
  {%- set on_amazonlinux_1 = False %}
{%- endif %}

{%- if os_family == 'RedHat' and os_major_release == 7 %}
  {%- set on_redhat_7 = True %}
{%- else %}
  {%- set on_redhat_7 = False %}
{%- endif %}

{%- if os_family == 'Debian' and distro == 'wheezy' %}
  {%- set on_debian_7 = True %}
{%- else %}
  {%- set on_debian_7 = False %}
{%- endif %}

{%- if os_family == 'Arch' %}
  {%- set on_arch = True %}
{%- else %}
  {%- set on_arch = False %}
{%- endif %}

{%- if os_family == 'Ubuntu' and os_major_release == 14 %}
  {%- set on_ubuntu_14 = True %}
{%- else %}
  {%- set on_ubuntu_14 = False %}
{%- endif %}

{%- if grains['os'] == 'MacOS' %}
  {%- set on_macos = True %}
{%- else %}
  {%- set on_macos = False %}
{%- endif %}

{%- if os_family == 'Windows' %}
  {%- set on_windows=True %}
{%- else %}
  {%- set on_windows=False %}
{%- endif %}

{%- if os == 'Fedora' %}
  {%- set force_reinstall = '--force-reinstall' %}
{%- else %}
  {%- set force_reinstall = '' %}
{%- endif %}

{%- set pip2 = 'pip2' %}
{%- set pip3 = 'pip3' %}

{%- if on_windows %}
  {#- TODO: Maybe run this by powershell `py.exe -3 -c "import sys; print(sys.executable)"` #}
  {%- set python2 = 'c:\\\\Python27\\\\python.exe' %}
  {%- set python3 = 'c:\\\\Python35\\\\python.exe' %}
{%- else %}
  {%- if on_redhat_6 or on_amazonlinux_1 %}
    {%- set python2 = 'python2.7' %}
  {%- else %}
    {%- set python2 = 'python2' %}
  {%- endif %}
  {%- if on_redhat_7 %}
    {%- set python3 = 'python3.6' %}
  {%- else %}
    {%- set python3 = 'python3' %}
  {%- endif %}
{%- endif %}


{%- if (not on_redhat_6 and not on_ubuntu_14 and not on_windows) or (on_windows and pillar.get('py3', False)) %}
  {%- set install_pip3 = True %}
{%- else %}
  {%- set install_pip3 = False %}
{%- endif %}

{%- if not on_windows or (on_windows and pillar.get('py3', False) == False) %}
  {%- set install_pip2 = True %}
{%- else %}
  {%- set install_pip2 = False %}
{%- endif %}

include:
{%- if pillar.get('py3', False) %}
  {%- if not on_redhat_6 and not on_ubuntu_14 %}
  - python3
  {%- endif %}
{%- else %}
  {%- if on_arch or on_windows %}
  - python27
  {%- endif %}
{%- endif %}
{%- if on_debian_7 %}
  - python.headers
{%- endif %}
  {%- if install_pip3 and grains['os'] == 'Ubuntu' and os_major_release >= 18 %}
  - python.distutils
  {%- endif %}
  - noop-placeholder {#- Make sure there's at least an entry in this 'include' statement #}

{%- set get_pip2 = '{} {} {}'.format(python2, get_pip_path, force_reinstall) %}
{%- set get_pip3 = '{} {} {}'.format(python3, get_pip_path, force_reinstall) %}

{%- if grains['os'] == 'openSUSE' %}
  {%- set ca_certificates = 'ca-certificates-mozilla' %}
{%- else %}
  {%- set ca_certificates = 'ca-certificates' %}
{%- endif %}

{% set openssl = 'openssl' %}
openssl:
  pkg.latest:
    - name: {{ openssl }}
 
{% set wget = 'wget' %}
wget:
  pkg.latest:
    - name: {{ wget }}

{% if grains['os_family'] == 'RedHat' and grains['osmajorrelease'][0] == '5' %}
download-ca-certificates:
  cmd.run:
    - name: wget -O /etc/pki/tls/certs/ca-bundle.crt http://curl.haxx.se/ca/cacert.pem
    - require:
      - pkg: wget
      - pkg: openssl
{%- else %}
install-ca-certificates:
  pkg.latest:
    - name: {{ ca_certificates }}
    - require:
      - pkg: openssl
{%- endif %}

ca-certificates:
  test.succeed_with_changes:
    - watch:
      {%- if grains['os_family'] == 'RedHat' and grains['osmajorrelease'][0] == '5' %}
      - cmd: download-ca-certificates
      {%- else %}
      - pkg: install-ca-certificates
      {%- endif %}
      
{% if grains['os'] == 'Arch' %}
  {% set python = 'python2' %}
{% elif grains['os_family'] == 'RedHat' and grains['osmajorrelease'][0] == '5' %}
  {% set python = 'python27' %}
{% else %}
  {% set python = 'python' %}
{% endif %}

{%- if grains['os'] == 'Arch' %}
  {% set pip = 'python2-pip' %}
{%- elif grains['os_family'] == 'RedHat' and grains['osmajorrelease'][0] == '5' %}
  {% set pip = 'python26-pip' %}
{%- else %}
  {% set pip = 'python-pip' %}
{%- endif %}

python-pip:
  pkg.latest:
    - name: {{ pip }}
    - upgrade: true
    - reload_modules: true
    - require:
      - test: ca-certificates
      
{#- Ubuntu Lucid and CentOS 5 has way too old pip package, we'll need to upgrade "by hand", salt can't do it for us #}
{% if (grains['os'] == 'Ubuntu' and grains['osrelease'].startswith('10.')) or (grains['os'] == 'CentOS' and grains['osrelease'].startswith('5.')) %}
uninstall-python-pip:
  pkg.purged:
    - name: {{ pip }}
pip-cmd:
  cmd.run:
    - name: wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O - | {{ python }}
    - require:
      - pkg: uninstall-python-pip
    - reload_modules: true
{% endif %}
pip:
  pip.install:
    {%- if salt['config.get']('virtualenv_name', None) %}
    - bin_env: /srv/virtualenvs/{{ salt['config.get']('virtualenv_name') }}
    {%- endif %}
    - index_url: https://pypi-jenkins.saltstack.com/jenkins/develop
    - extra_index_url: https://pypi.python.org/simple
    - upgrade: true
    - reload_modules: true
    - require:
      {%- if grains['os'] == 'Ubuntu' and grains['osrelease'].startswith('10.') %}
      - cmd: pip-cmd
      {%- else %}
      - pkg: python-pip
      {%- endif %}
