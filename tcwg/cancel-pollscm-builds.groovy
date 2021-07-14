def cancelPreviousBuilds() {{
  // Check for other instances of this particular build, cancel any that are older than the current one
  def jobName = env.JOB_NAME
  def currentJob = Jenkins.instance.getItemByFullName(jobName)
  def currentBuildNumber = env.BUILD_NUMBER.toInteger()

  // Loop through all instances of this particular job/branch
  for (def build : currentJob.builds) {{
    if (build.hasntStartedYet() && (build.number.toInteger() != currentBuildNumber) && (build.GetCauses(Cause.SCMTriggerCause) != null)) {{
      echo "Older build still queued. Sending kill signal to build number: ${{build.number}}"
      build.doStop()
    }}
  }}
}}

cancelPreviousBuilds()
