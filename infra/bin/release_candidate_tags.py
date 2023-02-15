#!/usr/bin/env python3

import argparse
import semver
from functools import cmp_to_key

try:
    from git import Repo, Commit
except ImportError:
    print("Error: gitpython not found.")
    print("run `pip install gitpython`")
    exit(1)


help_text = """
Bumps release-candidate tags while the project is in the release-flow for the release branches.
(Typical used by CircleCI while in staging lifecycle after a successful test suite)

Usage:
    python3 infrastructure/make-utils/bin/release_candidate_tags.py \
        -b "origin/gateway/release/0.5.2" \
        -d gateway

    Outputs:
    > branch: origin/gateway/release/0.5.2
    > latest tag: tags/gateway/release/0.5.2-rc.15
    > Created new tag: tags/gateway/release/0.5.2-rc.16

"""


def main(branch: str):
    repo = Repo(".", search_parent_directories=True)
    print(f"branch: {branch}")
    tags = repo.git.tag("--merged", f"origin/{branch}")
    tags = [tag for tag in tags.split("\n") if tag.startswith(f"tags/{branch}")]
    if len(tags) == 0:
        print(f"No tags found corresponding to the branch {branch}.\n"
              f"Release branches should be of the form `<project>/release/<SemVer>`")
        return "branch"
    latest_tag = max(tags, default=None, key=cmp_to_key(tag_comparison))
    print(f"latest_tag: {latest_tag}")
    new_version = semver.bump_prerelease(latest_tag.split('/')[-1])
    new_tag = "/".join(latest_tag.split('/')[:-1]+[new_version])
    repo.config_writer().set_value("user", "name", "CircleCI System User").release()
    repo.config_writer().set_value("user", "email", "github-murine-bot@murine.org").release()
    repo.create_tag(new_tag, message=f"Release candidate {new_tag}")
    repo.remote().push(refspec=f"refs/tags/{new_tag}")
    print(f"Created new tag: {new_tag}")


def tag_comparison(v1, v2):
    return semver.compare(v1.split('/')[-1], v2.split('/')[-1])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=help_text, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-b",
        "--branch",
        help="release branch, e.g. api/release/1.0.0",
        type=str,
        required=True,
    )
    pargs = parser.parse_args()
    main(pargs.branch)
