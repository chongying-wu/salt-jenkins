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


{%- set python = salt['pillar.get']('python', []) %}
{%- set proxy_url = salt['pillar.get']('proxy_url', None) %}

python_packages:
  pkg.installed:
    - pkgs:
      - python
      - python-setuptools
      {%- if salt['grains.get']('os_family') == 'Debian' %}
      - python3
      - python3-setuptools
      {%- elif salt['grains.get']('os_family') == 'RedHat' %}
      - epel-release
      - python34
      - python34-setuptools
      {%- endif %}

{%- if (salt['grains.get']('lsb_distrib_release') == '18.04' and salt['grains.get']('lsb_distrib_id') == 'Ubuntu') %}
python2-pip:
  pkg.installed:
    - pkgs:
      - python-pip
      - python3-pip

install_pip2:
  cmd.run:
    - name: echo 'This is for you, vault_pki <3'
    - require:
      - pkg: python2-pip
{%- else %}
purge_pip:
  pkg.removed:
    - pkgs:
      - python-pip
      {%- if salt['grains.get']('os_family') == 'Debian' %}
      - python-pip-whl
      - python3-pip
      - python3-pip-whl
      {%- endif %}
install_pip2:
  cmd.run:
    - name: easy_install pip==9.0.3
    {%- if salt['grains.get']('os_family') == 'Debian' %}
    - unless: test -x /usr/local/bin/pip2 -a $(pip --version| awk {'print $2'}) = "9.0.3"
    {%- elif salt['grains.get']('os_family') == 'RedHat' %}
    - unless: test -x /usr/bin/pip2 -a $(pip --version| awk {'print $2'}) = "9.0.3"
    {%- endif %}
    {%- if proxy_url %}
    - env:
      - http_proxy: {{ proxy_url }}
      - https_proxy: {{ proxy_url }}
    {%- endif %}
    - reload_modules: true
    - require:
      - pkg: python_packages
      - pkg: purge_pip
# Dummy to match "python2-formula" FL/OSS formula for
# making compatible requisites in "vault-pki-formula"..
python2-pip:
  pkg.installed:
    - name: python
    - require:
      - cmd: install_pip2
install_pip3:
  cmd.run:
    {%- if salt['grains.get']('os_family') == 'Debian' %}
    - name: easy_install3 pip
    - unless: test -x /usr/local/bin/pip3
    {%- elif salt['grains.get']('os_family') == 'RedHat' %}
    - name: easy_install-3.4 pip
    - unless: test -x /usr/bin/pip3
    {%- endif %}
    {%- if proxy_url %}
    - env:
      - http_proxy: {{ proxy_url }}
      - https_proxy: {{ proxy_url }}
    {%- endif %}
    - reload_modules: true
    - require:
      - pkg: python_packages
      - pkg: purge_pip
# Point pip to our local proxy cache/custom server
{%- if python or proxy_url %}
/etc/pip.conf:
  file.managed:
    - source: salt://python/files/pip.conf.jinja
    - makedirs: true
    - template: jinja
{%- endif %}
{%- endif %} # if (salt['grains.get']('lsb_distrib_release') == '18.04' and salt['grains.get']('lsb_distrib_id') == 'Ubuntu')
