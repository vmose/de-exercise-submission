{% macro parse_number(column) %}
    try_cast(replace(replace({{ column }}, ',', ''), ' ', '') as double)
{% endmacro %}
