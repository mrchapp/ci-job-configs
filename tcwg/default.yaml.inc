# -*- mode: Yaml -*-

- property:
    name: default-properties
    properties:
      - authorization:
          anonymous:
            - job-read
            - job-extended-read
          linaro:
            - job-build
            - job-cancel
#if TCWG_benchmark
          # Allow users in tcwg-benchmark group (e.g., tcwg-buildslave)
          # start and stop builds.  We use this in tcwg_bmk* CI loops.
          tcwg-benchmark:
            - job-build
            - job-cancel
#endif
      - build-discarder:
          days-to-keep: 30
#if TCWG_benchmark
          num-to-keep: 100
#else
          num-to-keep: 30
#endif

#if JENKINS_SCRIPTS_master
- scm:
    name: jenkins-scripts-master
    scm:
      - git:
          url: https://git.linaro.org/toolchain/jenkins-scripts.git
          refspec: +refs/heads/master:refs/remotes/origin/master
          branches:
            - master
          basedir: jenkins-scripts
          skip-tag: true
          reference-repo: /home/tcwg-buildslave/snapshots-ref/jenkins-scripts.git
          wipe-workspace: false
          clean:
            before: true
          prune: true
#else
- scm:
    name: jenkins-scripts
    scm:
      - git:
          url: https://git.linaro.org/toolchain/jenkins-scripts.git
          refspec: +refs/heads/*:refs/remotes/origin/* +refs/changes/*:refs/changes/*
          branches:
            - $scripts_branch
          basedir: jenkins-scripts
          skip-tag: true
          reference-repo: /home/tcwg-buildslave/snapshots-ref/jenkins-scripts.git
          wipe-workspace: false
          clean:
            before: true
          prune: true
#endif

#if RR_tcwg_bmk || TCWG_benchmark
- scm:
    name: bmk-scripts
    scm:
      - git:
          url: https://git.linaro.org/toolchain/bmk-scripts.git
          refspec: +refs/heads/*:refs/remotes/origin/* +refs/changes/*:refs/changes/*
          branches:
            - $bmk_branch
          basedir: bmk-scripts
          skip-tag: true
          reference-repo: /home/tcwg-buildslave/snapshots-ref/bmk-scripts.git
          wipe-workspace: false
          clean:
            before: true
          prune: true
#endif
