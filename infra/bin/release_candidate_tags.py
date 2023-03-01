#!/usr/bin/env python3

import argparse
import semver
from functools import cmp_to_key
from git import Repo, Commit


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
    tags = repo.git.ls_remote("--tags", f"origin")
    tag_names = [tag.split("refs/tags/")[1] for tag in tags.split("\n")]
    tag_names = [tag for tag in tag_names
                 if tag.startswith(f"tags/{branch}")
                 and semver.VersionInfo.isvalid(tag.split('/')[-1])]
    print (tag_names)
    if len(tag_names) == 0:
        print(f"No tags found corresponding to the branch {branch}.\n"
              f"Release branches should be of the form `<project>/release/<semver>`")
        return 0
    latest_tag = max(tag_names, default=None, key=cmp_to_key(tag_comparison))
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
