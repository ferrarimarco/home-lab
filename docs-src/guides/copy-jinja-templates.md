# Copy Jinja templates as they are

If you need to copy Jinja templates with the Ansible Template Module, you can
configure Ansible to change the variable start and end prefixes inside the template
by adding a special header.

For example:

```yaml
#jinja2:variable_start_string:'[%', variable_end_string:'%]'
```

Changes the default variable start and end prefixes from `{{` and `}}` to `[%` and `%]`.
