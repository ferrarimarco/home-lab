from argparse import ArgumentDefaultsHelpFormatter, ArgumentParser
import os
from jinja2 import Environment, FileSystemLoader


def render_template(template_load_path: str, template_file_path: str):
    """Render a Jinja template.
    Args:
     project_id: The Google Cloud project ID to generate a JWT for.
     google_cloud_region: Google Cloud region where the IoT Core registry resides.
     iot_core_registry_id: ID of the Cloud IoT Core registry where you registered the device in.
     oauth2_scopes: List of Oauth 2.0 scopes to request access to.
     jwt: JWT to authenticate the request.
    Returns:
        The requested Oauth 2.0 for the specified IoT Core device.
    """
    file_loader = FileSystemLoader(template_load_path)
    env = Environment(loader=file_loader, trim_blocks=True)

    template = env.get_template(template_file_path)

    output = template.render()
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

    return parser, vars(parser.parse_args(args))


def main():
    parser, args = parse_arguments()

    try:
        func = args["function"]
    except KeyError:
        parser.error("No function defined. Terminating...")

    if func == render_template:
        result = render_template(args["template_load_path"], args["template_file_path"])
    else:
        parser.error("Unsupported command. Terminating...")

    print(result)


if __name__ == "__main__":
    main()
