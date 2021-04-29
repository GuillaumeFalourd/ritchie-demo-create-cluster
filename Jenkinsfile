node {
	  try {

	    buildTerraformEnv {
	      team = "Marte"
	    }

	  } catch (e) {
	      notifyBuildStatus {
	        buildStatus = "FAILED"
	      }
	      throw e
	  }

	}

	