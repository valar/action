import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as installer from './installer';


async function run() {
  const APIEndpoint = "https://api.valar.dev/v2";
  const APIToken = core.getInput('token', { required: true });
  const Workdir = core.getInput('workdir', { required: false });

  try {
    await installer.installValar();
    
    core.exportVariable("VALAR_TOKEN", APIToken);
    core.exportVariable("VALAR_ENDPOINT", APIEndpoint);
    core.debug("Submitting build to Valar ...")

    // Wait for build ID
    const options: exec.ExecOptions = {
      listeners: {
            stdout: (data: Buffer) => {
                output += data.toString();
            },
            stderr: (data: Buffer) => {}
        }
    };

    if (Workdir) {
      options.cwd = Workdir
    }

    let output = '';
    await exec.exec('valar', ['push'], options);
    let buildID = output.trim();
    
    console.log("Submitted build with ID " + buildID);
  } catch (error) {
      let message
      if (error instanceof Error) message = error.message
      else message = String(error)
    
      core.setFailed(message);
  }
}

run();
