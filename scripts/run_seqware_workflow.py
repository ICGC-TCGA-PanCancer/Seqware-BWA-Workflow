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
import os
import re
import subprocess
import sys
import tempfile

# set global variables
global workflow_version
global workflow_bundle
global workflow_bundle_dir
workflow_version = "2.6.8"
workflow_bundle = "Workflow_Bundle_BWA"
workflow_bundle_dir = "".join(
    ["/home/seqware/Seqware-BWA-Workflow/target/",
     workflow_bundle,
     "_",
     workflow_version,
     "_SeqWare_1.1.1/"]
)


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
        "--output-file-basename",
        dest="output_file_basename",
        type=str,
        help="all output files will have this basename")
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
    work_dir = os.environ['PWD']
    execute("export TMPDIR=/tmp")
    execute("export HOME=%s" % work_dir)
    execute("whoami")
    execute("gosu root chown -R seqware /data")
    execute("gosu root chown -R seqware /home/seqware")
    execute("gosu root chmod -R a+wrx /home/seqware");
    execute("gosu root mkdir -p %s/.seqware" % work_dir);
    execute("gosu root chown -R seqware %s" % work_dir);
    execute("gosu root cp /home/seqware/.seqware/settings %s/.seqware" % work_dir);
    execute("gosu root chmod a+wrx %s/.seqware/settings" % work_dir);
    execute("perl -pi -e 's/wrench.res/seqwaremaven/g' /home/seqware/bin/seqware");
    dest = os.path.join(workflow_bundle_dir,
                        workflow_bundle,
                        workflow_version,
                        "/data/reference/bwa-0.6.2/")

    if not os.path.isdir(dest):
        execute("mkdir -p {0}".format(dest))

    # symlink reference files to dest
    for key, val, in vars(args).iteritems():
        if val is not None and re.match("reference", key):
            execute("ln -s {0} {1}".format(os.path.abspath(val), dest))

    execute("ls -lth {0}".format(dest))


def write_ini(args):
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

    outdir = os.path.abspath(args.output_dir)
    workflow_output_dir = outdir.split("/")[-1]
    output_prefix = re.sub(workflow_output_dir, "", outdir)

    ini_parts = ["input_bam_paths={}".format(",".join(args.files)),
                 "input_file_urls={}".format(",".join(file_urls)),
                 "download_reference_files={}".format(args.download_refs),
                 "input_reference={}".format(
                     os.path.join(workflow_bundle_dir,
                                  workflow_bundle,
                                  workflow_version,
                                  "/data/reference/bwa-0.6.2/",
                                  os.path.basename(args.reference_gz))
                 ),
                 # GNOS
                 "useGNOS={}".format(args.useGNOS),
                 "gnos_input_metadata_urls={}".format(",".join(metadata_urls)),
                 "use_gtdownload={}".format(args.use_gtdownload),
                 "use_gtupload={}".format(args.use_gtupload),
                 "use_gtvalidation={}".format(args.use_gtvalidation),
                 "gnos_timeout_min={}".format("6"),
                 "skip_upload={}".format("true"),
                 "gnos_key={}".format(
                     os.path.join(workflow_bundle_dir,
                                  workflow_bundle,
                                  workflow_version,
                                  "scripts/gnostest.pem")
                 ),
                 "gnos_max_children={}".format("8"),
                 "gnos_rate_limit={}".format("200"),
                 "gnos_timout={}".format("40"),
                 # Output
                 "cleanup={}".format("false"),
                 "output_dir={}".format(workflow_output_dir),
                 "output_prefix={}".format(output_prefix),
                 # PICARD
                 "picardSortMem={}".format("4"),
                 "picardSortJobMem={}".format("6"),
                 "additionalPicardParams={}".format(""),
                 # BWA
                 "bwaAlignMemG={}".format("8"),
                 "bwaSampeMemG={}".format("8"),
                 "bwaSampeSortSamMemG={}".format("4"),
                 "bwa_choice={}".format("mem"),
                 "bwa_aln_params={}".format(""),
                 "bwa_mem_params={}".format(""),
                 "bwa_sampe_params={}".format(""),
                 "maxInsertSize={}".format(""),
                 "readGroup={}".format(""),
                 # Threads - used for BWA, bamsort, bammarkduplicates
                 "numOfThreads={}".format("8"),
                 # Extract unmapped reads
                 "unmappedReadsJobMemM={}".format("8000"),
                 # Upload script
                 "uploadScriptJobMem={}".format("3"),
                 # GT Download
                 "gtdownloadRetries={}".format("30"),
                 "gtdownloadMd5time={}".format("120"),
                 "gtdownloadMemG={}".format("8"),
                 "gtdownloadWrapperType={}".format("timer_based"),
                 # Misc
                 "smallJobMemM={}".format("4000"),
                 "study-refname-override={}".format("icgc_pancancer"),
                 "analysisCenter={}".format("OICR"),
                 # Slots
                 "bwaAlignSlots={}".format("8"),
                 "bwaSampleSlots={}".format("8"),
                 "picardSortJobSlots={}".format("4"),
                 "uploadScriptJobSlots={}".format("4"),
                 "gtdownloadSlots={}".format("8"),
                 "smallJobSlots={}".format("2"),
                 "unmappedReadsJobMemSlots={}".format("4"),
                 "unmappedReadsJobSlots={}".format("4")]

    ini = "\n".join(ini_parts)
    ini_filepath = os.path.join(outdir, "workflow.ini")
    with open(ini_filepath, 'wb') as f:
        f.write(ini)
    return ini_filepath

def execute(cmd):
    print("RUNNING...\n", cmd, "\n")
    with tempfile.NamedTemporaryFile() as errfile:
        process = subprocess.Popen(cmd,
                               shell=True,
                               stdout=subprocess.PIPE,
                               stderr=errfile)

        while True:
            nextline = process.stdout.readline()
            if nextline == '' and process.poll() is not None:
                break
            sys.stdout.write(nextline)
            sys.stdout.flush()

        stderr = process.communicate()[1]

        if process.returncode != 0:
            print(
                "[ERROR] command:", cmd, "exited with code:", process.returncode,
                file=sys.stderr
            )
            print(stderr, file=sys.stderr)
            raise
        else:
            return process.returncode



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

    # PUT REF FILES IN THE RIGHT PLACE
    link_references(args)

    output_dir = os.path.abspath(args.output_dir)
    if not os.path.isdir(output_dir):
        # Make the output directory if it does not exist
        execute("mkdir -p {0}".format(output_dir))

    # WRITE WORKFLOW INI
    ini_file = write_ini(args)

    # RUN WORKFLOW
    cmd_parts = ["seqware bundle launch",
                 "--dir {}".format(workflow_bundle_dir),
                 "--engine whitestar",
                 "--ini {}".format(ini_file),
                 "--no-metadata"]
    cmd = " ".join(cmd_parts)
    execute(cmd)

    # FIND OUTPUT
    path = glob.glob("/datastore/oozie-*")[0]
    results_dir = os.path.join(path, "data")

    # NAME & MOVE OUTPUT FILES
    if args.output_file_basename is None:
        basenames = []
        for f in args.files:
            basenames.append(
                re.sub("[_]?unaligned[_]?|\.bam$", "", os.path.basename(f))
            )
        if basenames.count(basenames[0]) == len(basenames):
            output_file_basename = basenames[0]
        else:
            output_file_basename = "_".join(basenames)
    else:
        output_file_basename = args.output_file_basename

    # FIND ALL OUTPUT FILES
    output_files = glob.glob(
        os.path.join(results_dir, "merged_output*")
    )

    # RENAME OUTPUT FILES
    for f in output_files:
        new_f = output_file_basename
        f_suffix = re.sub("merged_output", "", os.path.basename(f))
        new_f += f_suffix
        print(f, new_f)
        execute(
            "mv {0} {1}".format(f, os.path.join(output_dir, new_f))
        )


if __name__ == "__main__":
    main()
