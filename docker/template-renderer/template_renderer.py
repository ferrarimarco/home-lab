import os
from jinja2 import Environment, FileSystemLoader

template_load_path = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "templates"
)

file_loader = FileSystemLoader(template_load_path)
env = Environment(loader=file_loader, trim_blocks=True)

template = env.get_template("cloud-init/user-data.yaml.jinja")

output = template.render()
print(output)
