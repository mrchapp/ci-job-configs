def cancelPreviousBuilds() {
	// Check for other instances of this particular build, cancel any that are older than the current one
	def jobName = env.JOB_NAME;
	def currentJob = Jenkins.instance.getItemByFullName(jobName);
	def currentBuildNumber = env.BUILD_NUMBER.toInteger();

	// Loop through all instances of this particular job/branch
	def stop_myself = false;
	def keep_scm_build = 0;

	println("DEBUG: Scanning");
	for (def build : currentJob.builds) {
		if (!build.hasntStartedYet() && build.number.toInteger() != currentBuildNumber) {
			continue;
		}

		if (build.GetCauses(Cause.SCMTriggerCause) != null) {
			if (keep_scm_build < build.number.toInteger()) {
				keep_scm_build = build.number.toInteger();
			}
		} else {
			keep_scm_build = 0;
		}
	}

	println("DEBUG: keep_scm_build #${keep_scm_build}");

	def killCurrentBuild = null;
	for (def build : currentJob.builds) {
		if (!build.hasntStartedYet() && build.number.toInteger() != currentBuildNumber) {
			continue;
		}

		if (build.GetCauses(Cause.SCMTriggerCause) != null && build.number.toInteger() != keep_scm_build) {
			if (build.number.toInteger() != currentBuildNumber) {
				println("DEBUG: Stopping SCM build #${build.number.toInteger()}");
				build.doStop();
			} else {
				killCurrentBuild = build;
			}
		}
	}

	if (killCurrentBuild != null) {
		println("DEBUG: Stopping SCM self #${killCurrentBuild.number.toInteger()}");
		killCurrentBuild.doStop();
	}
}

cancelPreviousBuilds()
