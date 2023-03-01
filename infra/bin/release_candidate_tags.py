#!/usr/bin/env python3

import argparse
import semver
from semver import VersionInfo as VerInfo
from functools import cmp_to_key
from git import Repo
import os


help_text = """
Bumps release-candidate tags while the project is in the release-flow for the release branches.
(Used before deploying a release branch while in staging lifecycle after a successful test suite run)

Usage:
    python3 ../infrastructure/../release_candidate_tags.py \
        -b "origin/gateway/release/0.5.2" 

    Outputs:
    > branch: origin/gateway/release/0.5.2
    > latest tag: tags/gateway/release/0.5.2-rc.15
    > Created new tag: tags/gateway/release/0.5.2-rc.16

"""


def main(branch: str):
    repo = Repo(".", search_parent_directories=True)
    print(f"branch: {branch}")
    tags = [tag.split("refs/tags/")[1] for tag in repo.git.ls_remote("--tags", f"origin").split("\n")]
    candidate_tags = []
    for t in tags:
        if t.startswith(f"tags/{branch}"):
            rc_part = t.split('/')[-1]
            if VerInfo.isvalid(rc_part):
                candidate_tags.append(t)

    if len(candidate_tags) == 0:
        print(f"No candidate tags found corresponding to the branch {branch}.\n"
              f"Release branches should be of the form `<project>/release/<semver>`")
        return 0
    latest_tag = max(candidate_tags, default=None, key=cmp_to_key(tag_comparison))
    print(f"latest_tag: {latest_tag}")
    if VerInfo.parse(latest_tag.split('/')[-1]).prerelease is None:
        print("Latest tag is already a release tag. No further pre-releases can be done.")
        return 0
    new_version = semver.bump_prerelease(latest_tag.split('/')[-1])
    new_tag = "/".join(latest_tag.split('/')[:-1]+[new_version])
    repo.config_writer().set_value("user", "name", "CircleCI System User").release()
    repo.config_writer().set_value("user", "email", "github-murine-bot@murine.org").release()
    repo.create_tag(new_tag, message=f"Release candidate {new_tag}")
    repo.remote().push(refspec=f"refs/tags/{new_tag}")
    os.environ["RELEASE_VERSION"] = new_tag
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
