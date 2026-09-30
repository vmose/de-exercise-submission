{% macro name_key(name_expr) %}
    nullif(
        array_to_string(
            list_sort(
                list_filter(
                    str_split(regexp_replace(lower(trim({{ name_expr }})), '[^a-z ]', '', 'g'), ' '),
                    x -> x != ''
                )
            ),
            ' '
        ),
        ''
    )
{% endmacro %}
