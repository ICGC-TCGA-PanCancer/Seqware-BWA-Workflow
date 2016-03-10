#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
This script wraps calling a SeqWare workflow, in this case, the BWA workflow.
It reads param line options, which are easier to deal with in CWL, then
creates an INI file, and, finally, executes the workflow.  This workflow
is setup to run in local file mode so you just need to specify
the inputs.
"""
from __future__ import print_function

import argparse
import glob
import logging
import os
import re
import subprocess
import sys

# set global variable for workflow version
global workflow_version
workflow_version = "2.6.7"


def collect_args():
    descr = 'SeqWare-based BWA alignment workflow from the PCAWG project.'
    parser = argparse.ArgumentParser(
        description=descr
    )
    requiredArgs = parser.add_argument_group('required arguments')
    requiredArgs.add_argument(
        "--files",
        type=str,
        nargs="+",
        required=True,
        help="The relative BAM paths which are typically the UUID/bam_file.bam \
        for bams from a GNOS repo if use_gtdownload is true. If use_gtdownload \
        is false these should be full paths to local BAMs.")
    parser.add_argument(
        "--output-dir",
        dest="output_dir",
        type=str,
        default="/output/",
        help="directory in which to store the output of the workflow.")
    parser.add_argument(
        "--file-urls",
        dest="file_urls",
        type=str,
        nargs="+",
        required=False,
        help="The URLs that are used to download the BAM files. The URLs \
        should be in the same order as the BAMs for files. These are not \
        used if use_gtdownload is false.")
    parser.add_argument(
        "--file-metadata-urls",
        dest="file_metadata_urls",
        type=str,
        nargs="+",
        required=False,
        help="The URLs that are used to download the BAM file metadata. The \
        URLs should be in the same order as the BAMs for files. Metadata is \
        read from GNOS if useGNOS = 'true' of whether or not bams are downloaded \
        from there.")
    parser.add_argument("--reference-gz",
                        type=str,
                        required=False,
                        help="gzipped reference genome.")
    parser.add_argument("--reference-gz-fai",
                        type=str,
                        required=False,
                        help="gzipped reference genome index.")
    parser.add_argument("--reference-gz-amb",
                        type=str,
                        required=False,
                        help="")
    parser.add_argument("--reference-gz-ann",
                        type=str,
                        required=False,
                        help="")
    parser.add_argument("--reference-gz-bwt",
                        type=str,
                        required=False,
                        help="")
    parser.add_argument("--reference-gz-pac",
                        type=str,
                        required=False,
                        help="")
    parser.add_argument("--reference-gz-sa",
                        type=str,
                        required=False,
                        help="")
    parser.add_argument("--useGNOS",
                        type=str,
                        default="false",
                        choices=["true", "false"],
                        help="")
    parser.add_argument("--use-gtdownload",
                        dest="use_gtdownload",
                        type=str,
                        default="false",
                        choices=["true", "false"],
                        help="")
    parser.add_argument("--use-gtupload",
                        dest="use_gtupload",
                        type=str,
                        default="false",
                        choices=["true", "false"],
                        help="")
    parser.add_argument("--use-gtvalidation",
                        dest="use_gtvalidation",
                        type=str,
                        default="false",
                        choices=["true", "false"],
                        help="")
    parser.add_argument("--download-reference-files",
                        dest="download_refs",
                        type=str,
                        default="false",
                        choices=["true", "false"],
                        help="Download reference files from S3")
    return parser


def link_references(args):
    dest = "".join(
        ["/home/seqware/Seqware-BWA-Workflow/target/Workflow_Bundle_BWA_",
         workflow_version,
         "_SeqWare_1.1.1/Workflow_Bundle_BWA/",
         workflow_version,
         "/data/reference/bwa-0.6.2/"])

    if not os.path.isdir(dest):
        execute("mkdir -p {0}".format(dest))

    # symlink reference files to dest
    for key, val, in vars(args).iteritems():
        if val is not None and re.match("reference", key):
            execute("ln -s {0} {1}".format(os.path.abspath(val), dest))

    execute("ls -lth {0}".format(dest))


def write_ini(args, cwd):
    if args.file_urls is None:
        # Local mode
        assert args.useGNOS == "false"
        assert args.use_gtdownload == "false"
        assert args.use_gtupload == "false"
        assert args.use_gtvalidation == "false"
        # for padding
        file_urls = ["https://gtrepo-ebi.annailabs.com/cghub/data/analysis/download/<uuid>"] * len(args.files)
    else:
        file_urls = args.file_urls

    if args.file_metadata_urls is None:
        # Local mode
        assert args.useGNOS == "false"
        assert args.use_gtdownload == "false"
        assert args.use_gtupload == "false"
        assert args.use_gtvalidation == "false"
        # for padding
        metadata_urls = ["https://gtrepo-ebi.annailabs.com/cghub/metadata/analysisFull/<uuid>"] * len(args.files)
    else:
        metadata_urls = args.file_urls

    # check that arg lengths match up as expected
    assert len(metadata_urls) == len(args.files)
    assert len(file_urls) == len(args.files)

    output_dir = os.path.abspath(args.output_dir).split("/")[-1]
    output_prefix = re.sub(output_dir, "", os.path.abspath(args.output_dir))

    ini_parts = ["useGNOS={0}".format(args.useGNOS),
                 "use_gtdownload={0}".format(args.use_gtdownload),
                 "use_gtupload={0}".format(args.use_gtupload),
                 "use_gtvalidation={0}".format(args.use_gtvalidation),
                 "download_reference_files={0}".format(args.download_refs),
                 "cleanup={0}".format("false"),
                 "input_bam_paths={0}".format(",".join(args.files)),
                 "input_file_urls={0}".format(",".join(file_urls)),
                 "gnos_input_metadata_urls={0}".format(",".join(metadata_urls)),
                 "output_dir={0}".format(output_dir),
                 "output_prefix={0}".format(output_prefix)]

    ini = "\n".join(ini_parts)
    ini_file = os.path.join(cwd, "workflow.ini")
    with open(ini_file, 'wb') as f:
        f.write(ini)


def execute(cmd):
    logging.info("RUNNING: %s" % (cmd))
    print("RUNNING...\n", cmd, "\n")
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    if stderr is not None:
        print(stderr)
    if stdout is not None:
        print(stdout)
    return p.returncode


def main():
    parser = collect_args()
    args = parser.parse_args()

    if args.download_refs == "false":
        try:
            assert args.reference_gz is not None
            assert args.reference_gz_fai is not None
            assert args.reference_gz_amb is not None
            assert args.reference_gz_ann is not None
            assert args.reference_gz_bwt is not None
            assert args.reference_gz_pac is not None
            assert args.reference_gz_sa is not None
        except AssertionError:
            raise AssertionError("If download-reference-files is 'false', all reference files must be explicitly provided")

    cwd = os.getcwd()
    print("Current Working Directory: {}".format(cwd))

    # PUT REF FILES IN THE RIGHT PLACE
    link_references(args)

    # WRITE WORKFLOW INI
    write_ini(args=args, cwd=cwd)

    # RUN WORKFLOW
    cmd_parts = ["seqware bundle launch",
                 "--dir /home/seqware/Seqware-BWA-Workflow/target/Workflow_Bundle_BWA_{0}_SeqWare_1.1.1".format(workflow_version),
                 "--engine whitestar",
                 "--ini workflow.ini",
                 "--no-metadata"]
    cmd = " ".join(cmd_parts)
    execute(cmd)

    # FIND OUTPUT
    path = glob.glob("/datastore/oozie-*")[0]
    results_dir = os.path.join(path, "data")

    if not os.path.isdir(args.output_dir):
        # Need to use sudo since this is process is running as seqware        
        execute("sudo mkdir -p {0}".format(args.output_dir))

    # MOVE OUTPUT FILES TO THE OUTPUT DIRECTORY
    if os.path.isfile("{0}/merged_output.bam".format(results_dir)):
        # Ensure we can write to the output_dir
        execute("sudo chown -R seqware {0}".format(args.output_dir))
        execute("mv {0}/merged_output.bam* {1}".format(
            results_dir, args.output_dir))
        execute("mv {0}/merged_output.unmapped.bam* {1}".format(
            results_dir, args.output_dir))
    else:
        sys.stderr.write(
            "[ERROR] Could not find output files in:\n{0}".format(results_dir))


if __name__ == "__main__":
    main()
