include:
  - python.pip
{%- if pillar.get('py3', False) %}
{%- set itertools = 'more-itertools' %}
{%- else %}
{#- more-itertools 5.0.0 is the last version which supports Python 2.7 or 2x at all #}
{%- set itertools = 'more-itertools' %}
{%- endif %}

more-itertools:
  pip.installed:
    - name: '{{ itertools }}'
