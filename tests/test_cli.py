import pytest

from ruok.cli import parse_args


def test_cli_parser_supports_once_and_console_notification_mode() -> None:
    args = parse_args(["--once", "--console", "--interval", "60", "--model", "llava"])

    assert args.once is True
    assert args.console is True
    assert args.interval == 60
    assert args.model == "llava"


def test_cli_parser_rejects_non_positive_interval() -> None:
    with pytest.raises(SystemExit):
        parse_args(["--interval", "0"])
