import pytest

from ruok.cli import parse_args


def test_cli_parser_supports_once_and_console_notification_mode() -> None:
    args = parse_args(
        [
            "--once",
            "--console",
            "--interval",
            "60",
            "--model",
            "llava",
            "--max-screenshot-edge",
            "1200",
        ]
    )

    assert args.once is True
    assert args.console is True
    assert args.interval == 60
    assert args.model == "llava"
    assert args.max_screenshot_edge == 1200


def test_cli_parser_rejects_non_positive_interval() -> None:
    with pytest.raises(SystemExit):
        parse_args(["--interval", "0"])


def test_cli_parser_rejects_non_positive_screenshot_edge() -> None:
    with pytest.raises(SystemExit):
        parse_args(["--max-screenshot-edge", "0"])
