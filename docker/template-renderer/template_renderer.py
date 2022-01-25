from argparse import ArgumentDefaultsHelpFormatter, ArgumentParser, FileType
import os
import yaml
from jinja2 import Environment, FileSystemLoader


def render_template(
    template_load_path: str, template_file_path: str, template_data_files: list[str]
):
    """Render a Jinja template.
    Args:
     template_load_path: Path to the directory where templates are stored.
     template_file_path: Path to the template to render inside the directory where templates are stored.
     template_data_files: List of paths to the data files where template configuration values are stored.
    Returns:
        The rendered template.
    """
    file_loader = FileSystemLoader(template_load_path)
    env = Environment(
        autoescape=True, loader=file_loader, lstrip_blocks=True, trim_blocks=True
    )

    template = env.get_template(template_file_path)

    template_data = {}
    for template_data_file in template_data_files:
        with open(template_data_file, "r") as stream:
            template_data.update(yaml.safe_load(stream))

    output = template.render(template_data)
    return output


def parse_arguments(args: list[str] = None):
    parser = ArgumentParser(
        description="Render Jinja templates.",
        formatter_class=ArgumentDefaultsHelpFormatter,
        prog=os.path.basename(__file__),
    )
    subparsers = parser.add_subparsers(help="sub_command")

    render_template_parser = subparsers.add_parser(
        "render_template",
        formatter_class=ArgumentDefaultsHelpFormatter,
        help="Render the jinja template",
    )
    render_template_parser.set_defaults(function=render_template)
    render_template_parser.add_argument(
        "template_file_path",
        help="Path to the template file inside the directory where templates are stored.",
    )
    render_template_parser.add_argument(
        "--template_load_path",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates"),
        help="Path to the directory where templates are stored.",
    )
    render_template_parser.add_argument(
        "--template_data_file_paths",
        help="Paths to the YAML-formatted template configuration data file.",
        nargs="*",
    )

    return parser, vars(parser.parse_args(args))


def main():
    parser, args = parse_arguments()

    try:
        func = args["function"]
    except KeyError:
        parser.error("No function defined. Terminating...")

    if func == render_template:
        result = render_template(
            args["template_load_path"],
            args["template_file_path"],
            args["template_data_file_paths"],
        )
    else:
        parser.error("Unsupported command. Terminating...")

    print(result)


if __name__ == "__main__":
    main()
