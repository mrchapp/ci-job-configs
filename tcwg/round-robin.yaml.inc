# -*- mode: Yaml -*-

#include tcwg/default.yaml.inc

- parameter:
    name: default-parameters
    parameters:
      - string:
          name: ci_project
          default: '{ci_project}'
#if RR_tcwg_bmk
          description: "CI project ID; used as namespace for git branches and selects benchmarking hardware"
#else
          description: "CI project ID; used as namespace for git branches"
#endif
      - string:
          name: ci_config
          default: '{ci_config}'
          description: "CI configuration ID; used as name of git branches and selects build flags"
      - string:
          name: extra_build_params
          default: ""
          description: "Extra parameters to pass to the build script; can be used to override settings extracted from ci_project/ci_config"
      - string:
          name: mail_recipients
#if PURPOSE_ci
          default: default
#elif PURPOSE_dev
          default: first.last@linaro.org
#endif
          description: "Comma-separated list of email recipients"
      - string:
          name: distro
          default: '{distro}'
          description: 'Distro image to use'
      - string:
          name: scripts_branch
          default: master
          description: 'Scripts revision to use'
#if RR_tcwg_bmk
      - string:
          name: bmk_branch
          default: master
          description: 'Benchmark scripts revision to use'
#endif

- parameter:
    name: component-parameters
    parameters:
      - string:
          name: '{component}_git'
          default: '{default_git}'
          description: "{component} git_url#branch/sha1 to build, or 'default', 'baseline' or 'jenkins-scm'"

- parameter:
    name: build-parameters
    parameters:
#if COMPONENTS_binutils
      - component-parameters:
          component: binutils
          default_git: '{default_git}'
#endif
#if COMPONENTS_gcc
      - component-parameters:
          component: gcc
          default_git: '{default_git}'
#endif
#if COMPONENTS_gdb
      - component-parameters:
          component: gdb
          default_git: '{default_git}'
#endif
#if COMPONENTS_glibc
      - component-parameters:
          component: glibc
          default_git: '{default_git}'
#endif
#if COMPONENTS_newlib
      - component-parameters:
          component: newlib
          default_git: '{default_git}'
#endif
#if COMPONENTS_linux
      - component-parameters:
          component: linux
          default_git: '{default_git}'
#endif
#if COMPONENTS_llvm
      - component-parameters:
          component: llvm
          default_git: '{default_git}'
#endif
#if COMPONENTS_qemu
      - component-parameters:
          component: qemu
          default_git: '{default_git}'
#endif
      - choice:
          name: update_baseline
          choices:
            - update
            - reset
            - init
            - push
          description: "What to do with baseline in this build"
      - default-parameters:
          ci_project: '{ci_project}'
          ci_config: '{ci_config}'
          distro: '{distro}'

# Beware: git branch names need the 'refs/heads/' prefix while tags
# need 'refs/tags/'.
- scm:
    name: component-scm
    scm:
        - git:
            url: '{url}'
            branches:
              - '{branch}'
            basedir: '{component}'
            skip-tag: true
            reference-repo: '/home/tcwg-buildslave/snapshots-ref/{reference}'
            wipe-workspace: false
            clean:
              before: true
            prune: true

# SCMs must start with jenkins-scripts and then be ordered alphabetically.
# Same alphabetical order must be followed in .def files.  The reason behind
# this is that jenkins sets $GIT_COMMIT to sha1 of jenkins-scripts, and then
# sets $GIT_COMMIT_1, $GIT_COMMIT_2, etc. to sha1s of component SCM /in the
# order that they are declared here/.
- scm:
    name: build-scms
    scm:
      - jenkins-scripts
#if PURPOSE_ci
#if COMPONENTS_binutils
      - component-scm:
          component: binutils
          url: '{binutils_url}'
          branch: '{binutils_branch}'
          reference: binutils-gdb.git
#endif
#if COMPONENTS_gcc
      - component-scm:
          component: gcc
          url: '{gcc_url}'
          branch: '{gcc_branch}'
          reference: gcc.git
#endif
#if COMPONENTS_gdb
      - component-scm:
          component: gdb
          url: '{gdb_url}'
          branch: '{gdb_branch}'
          reference: binutils-gdb.git
#endif
#if COMPONENTS_glibc
      - component-scm:
          component: glibc
          url: '{glibc_url}'
          branch: '{glibc_branch}'
          reference: glibc.git
#endif
#if COMPONENTS_linux
      - component-scm:
          component: linux
          url: '{linux_url}'
          branch: '{linux_branch}'
          reference: linux.git
#endif
#if COMPONENTS_llvm
      - component-scm:
          component: llvm
          url: '{llvm_url}'
          branch: '{llvm_branch}'
          reference: llvm-project.git
#endif
#if COMPONENTS_newlib
      - component-scm:
          component: newlib
          url: '{newlib_url}'
          branch: '{newlib_branch}'
          reference: newlib.git
#endif
#if COMPONENTS_qemu
      - component-scm:
          component: qemu
          url: '{qemu_url}'
          branch: '{qemu_branch}'
          reference: qemu.git
#endif
#endif /* PURPOSE_ci */
#if RR_tcwg_bmk
      - bmk-scripts
#endif

- wrapper:
    name: build-wrappers
    wrappers:
      - timeout:
          timeout: '{timeout}'
      - timestamps
      - ssh-agent-credentials:
          # tcwg-buildslave user id
          users:
            - 'e0958a95-204f-4c14-a66c-5e2be6c5d50a'

- builder:
    name: trigger-followup-builds
    builders:
      - build-name-setter:
          name: 'artifacts/jenkins/build-name'
          file: true
      - conditional-step:
          # Only run if above succeeded
          # (a failed build is indicated by artifacts/failed)
          condition-kind: current-status
          steps:
            - shell: |
                #!/bin/bash
                set -ex
                for i in artifacts/trigger-build-* artifacts/trigger-bisect; do
                  if [ -f $i ]; then
                    echo "ci_project=$ci_project" >> $i
                    echo "ci_config=$ci_config" >> $i
                    echo "mail_recipients=$mail_recipients" >> $i
                    echo "distro=$distro" >> $i
                    echo "scripts_branch=$scripts_branch" >> $i
#if RR_tcwg_bmk
                    echo "bmk_branch=$bmk_branch" >> $i
#endif
                  fi
                done
            - trigger-builds:
                - project: '{rr_project}-build{job_suffix}'
                  parameter-factories:
                    - factory: filebuild
                      file-pattern: artifacts/trigger-build-*
                - project: '{rr_project}-bisect{job_suffix}'
                  property-file: artifacts/trigger-bisect
            - shell:
                command: |
                  #!/bin/bash
                  if [ -f artifacts/failed ]; then
                    exit $(cat artifacts/failed)
                  fi
                unstable-return: 125

- builder:
    name: run-build
    builders:
      - shell:
          command: |
            #!/bin/bash
            set -ex
            # Delete artifacts now to avoid re-using stale artifacts if
            # below docker-run.sh fails to start up a container.
            rm -rf artifacts/
            mkdir -p artifacts/jenkins

            dryruncmd=""

            # Skip SCM-triggered builds if there are other builds in
            # the queue.  We need to process all pending bisection-triggered
            # builds before fetching a new batch of upstream changes.
            if [ x"${{BUILD_CAUSE_SCMTRIGGER-false}}" = x"true" ]; then
              inQueue=$(curl -s "${{JOB_URL}}api/xml?tree=inQueue" \
                          | sed -e "s#.*<inQueue>\(.*\)</inQueue>.*#\1#")
              if [ x"$inQueue" = x"true" ]; then
                dryruncmd="echo SKIPPING SCM BUILD:"
                touch artifacts/jenkins/skip-scm-build
              fi
            fi

#if PURPOSE_ci
            build_name="#$BUILD_NUMBER"
#elif PURPOSE_dev
            build_name="#$BUILD_NUMBER-$ci_project/$ci_config"
#endif
            branch_opt=""
            # 1 to skip jenkins-scripts
            i=1
            for c in {components}; do
              eval "g=\$$$${{c}}_git"
#if PURPOSE_ci
              if [ x"$g" = x"default" ]; then
                if [ x"${{BUILD_CAUSE_SCMTRIGGER-false}}" = x"true" ]; then
                  g="jenkins-scm"
                else
                  g="baseline"
                fi
              fi
              if [ x"$g" = x"jenkins-scm" ]; then
                eval "g=\$GIT_URL_$i#\$GIT_COMMIT_$i"
              fi
              i=$(($i+1))
#endif
              if [ x"$g" != x"baseline" ]; then
                build_name="$build_name-$c"
                branch_opt="$branch_opt ==rr[${{c}}_git] $g"
              fi
            done

            $dryruncmd \
            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
#if RR_tcwg_bmk
              --ssh_info true \
#elif RR_tcwg_gnu_native || RR_tcwg_gcc
              --arch {docker_arch} \
              --node $NODE_NAME \
#endif
              -- \
              ./jenkins-scripts/{build_script} \
              %% artifacts/jenkins/manifest.sh \
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              $extra_build_params \
#if RR_tcwg_bmk
              --bmk_branch "$bmk_branch" \
#endif
              --scripts_branch "$scripts_branch" \
              $branch_opt \
              ==rr[mode] "jenkins-full" \
              ==rr[update_baseline] "$update_baseline" \
              --BUILD_URL "$BUILD_URL" &
            res=0 && wait $! || res=$?

            if [ $res != 0 ]; then
              echo $res > artifacts/failed
            fi

            if [ -f artifacts/jenkins/skip-scm-build ]; then
              build_name="$build_name-skip-scm-build"
            fi
            if [ -f artifacts/results ]; then
              build_name="$build_name-R$(tail -n1 artifacts/results)"
            fi
            if [ x"$update_baseline" != x"update" ]; then
              build_name="$build_name-$update_baseline"
            fi
            if [ -f artifacts/trigger-bisect ]; then
              build_name="$build_name-trigger-bisect"
            fi
            echo "$build_name" > artifacts/jenkins/build-name

            # If we didn't run the docker command
            if [ -n "$dryruncmd" ]; then
              # Mark build unstable aka a skipped config
              exit 125
            fi
          unstable-return: 125
      - trigger-followup-builds:
          rr_project: '{rr_project}'
          job_suffix: '{job_suffix}'

- publisher:
    name: build-publishers
    publishers:
        - archive:
            artifacts: 'artifacts/**'
            latest-only: false

- parameter:
    name: bisect-parameters
    parameters:
      - string:
          name: current_project
          default: ""
          description: "Project to bisect"
      - string:
          name: bad_git
          default: ""
          description: "Bad git_url#branch/SHA1"
      - file:
          name: jenkins-scripts/replay_log
          description: "Replay part of bisect using provided bisect log"
      - default-parameters:
          ci_project: '{ci_project}'
          ci_config: '{ci_config}'
          distro: '{distro}'

- wrapper:
    name: bisect-wrappers
    wrappers:
      - build-wrappers:
          timeout: '{timeout}'
#if PURPOSE_ci
      - credentials-binding:
          - text:
              credential-id: TCWG_JIRA_TOKEN
              variable: TCWG_JIRA_TOKEN
#endif

- builder:
    name: run-bisect
    builders:
      - shell:
          command: |
            #!/bin/bash
            set -ex
            # Delete artifacts now to avoid re-using stale artifacts if
            # below docker-run.sh fails to start up a container.
            rm -rf artifacts/
            mkdir -p artifacts/jenkins
#if PURPOSE_ci
            build_name="#$BUILD_NUMBER-$current_project"
#elif PURPOSE_dev
            build_name="#$BUILD_NUMBER-$ci_project/$ci_config-$current_project"
#endif
            echo "$build_name" > artifacts/jenkins/build-name
            # artifacts/jenkins/mail-*.txt will be overwritten in successful builds.
            echo "maxim.kuvyrkov@linaro.org" > artifacts/jenkins/mail-recipients.txt
            echo "[TCWG CI] Bisect failed" > artifacts/jenkins/mail-subject.txt
            echo "Bisect $BUILD_URL failed" > artifacts/jenkins/mail-body.txt

            ./jenkins-scripts/docker-run.sh \
              --distro $distro \
#if RR_tcwg_bmk
              --ssh_info true \
#elif RR_tcwg_gnu_native || RR_tcwg_gcc
              --arch {docker_arch} \
              --node $NODE_NAME \
#endif
              -- \
              ./jenkins-scripts/round-robin-bisect.sh \
              %% artifacts/manifests/bisect.sh \
              --BUILD_URL "$BUILD_URL" \
              --current_project "$current_project" \
              --bad_git "$bad_git" \
              --replay_log "$(pwd)/jenkins-scripts/replay_log" \
              --build_script "./jenkins-scripts/{build_script}" \
#if PURPOSE_ci
              --TCWG_JIRA_TOKEN "$TCWG_JIRA_TOKEN" \
#endif
              -- \
              ==rr[ci_project] $ci_project \
              ==rr[ci_config] $ci_config \
              $extra_build_params \
#if RR_tcwg_bmk
              --bmk_branch "$bmk_branch" \
#endif
              --scripts_branch "$scripts_branch" &
            res=0 && wait $! || res=$?

            if [ $res != 0 ]; then
              echo $res > artifacts/failed
            fi

            if [ x"$mail_recipients" != x"default" ]; then
              echo "$mail_recipients" > artifacts/jenkins/mail-recipients.txt
            fi
          unstable-return: 125
      - trigger-followup-builds:
          rr_project: '{rr_project}'
          job_suffix: '{job_suffix}'

- publisher:
    name: bisect-publishers
    publishers:
        - build-publishers
        - email-ext:
            # Strangely, we no longer need to double-{ ${FILE} macro in
            # recipients and body sections.  They appear to bypass
            # job-template expansion.
            recipients: |
              ${FILE,path="artifacts/jenkins/mail-recipients.txt"}
            subject: |
              ${FILE,path="artifacts/jenkins/mail-subject.txt"}
            content-type: text
            body: |
              ${FILE,path="artifacts/jenkins/mail-body.txt"}
            failure: true
            success: true
            aborted: true
            send-to:
              - recipients
