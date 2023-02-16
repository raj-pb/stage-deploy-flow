#!/usr/bin/env python3

import argparse
from typing import List

try:
    from git import Repo, Commit
except ImportError:
    print("Error: gitpython not found.")
    print("run `pip install gitpython`")
    exit(1)

help_text = """
Generates release notes between two branches.

Usage:
    python3 infrastructure/make-utils/bin/release_notes.py \
        -s "origin/gateway/release/0.5.2" \
        -e "gateway/release/0.6.0" \
        -d gateway
    
    Outputs:
    > start branch: origin/gateway/release/0.5.2
    > end branch:   gateway/release/0.6.0

    > 8b8a73f9 2022-12-08 davidrideout Bump version 0.5.2 -> 0.6.0 
    > c19c23f6 2022-12-07 neil-at-TLR DEVOPS-224 stop installing docker.com docker (#1040)
    ...
     
"""


def format_commit(commit: Commit) -> str:
    """
    Returns a formatted commit
    :param commit:
    :return:
    """
    author = commit.author.name
    sha = commit.hexsha
    timestamp = commit.committed_datetime

    messages = []
    for msg in commit.message.split("\n"):
        msg = msg.strip()
        if msg:
            messages.append(msg)

    jira_tickets = set()
    # TODO (DR): Revisit, jira tickets are written as PROJECT-123, or sometimes "Project 123", etc.
    #            Tickets are not always referenced in commit messages, or some commits have no ticket
    #            reference.
    # matches = re.findall(r"((mus|devops|ml|fe)-\d+)", commit.message, re.IGNORECASE | re.MULTILINE)
    # if matches:
    #     for match in matches:
    #         jira_tickets.add(match[0].upper())

    return f"""{sha[:8]} {timestamp.strftime("%Y-%m-%d")} {author} {messages[0]} {','.join(jira_tickets)}"""


def main(from_branch: str, to_branch: str, paths: List[str]):
    """
    Does a git between two branches and outputs a commit log.

    :param from_branch: start branch, full path, e.g. origin/api/release/1.0.0
    :param to_branch: end branch, full path, e.g. origin/api/release/2.0.0
    :param paths: only outputs commits matching these paths
    :return:
    """

    repo = Repo(".", search_parent_directories=True)
    print(f"start branch: {from_branch}")
    print(f"end branch:   {to_branch}")
    print()
    commits = repo.iter_commits(f"{from_branch}..{to_branch}", paths=paths)
    for commit in commits:
        print(format_commit(commit))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=help_text, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-s",
        "--start",
        help="start release branch, e.g. api/release/1.0.0",
        type=str,
        required=True,
    )
    parser.add_argument(
        "-e",
        "--end",
        help="end release branch, e.g. api/release/2.0.0",
        type=str,
        required=True,
    )
    parser.add_argument(
        "-d",
        "--dir",
        help="project directory to filter",
        type=str,
        required=True,
    )

    pargs = parser.parse_args()
    main(pargs.start, pargs.end, pargs.dir)
