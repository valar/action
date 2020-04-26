import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as installer from './installer';


async function run() {
  const APIEndpoint = "https://api.valar.dev/v1";
  const APIToken = core.getInput('token', { required: true });

  try {
    await installer.installValar()

    // Wait for build ID
    let buildID = '';
    await exec.exec('valar', ['--api-token', APIToken, '--api-endpoint', APIEndpoint, 'push'], {
        listeners: {
            stdout: (data: Buffer) => {
                buildID += data.toString();
            },
            stderr: (data: Buffer) => {}
        }
    });

    // Follow build logs
    await exec.exec('valar', ['builds', 'logs', '-f', buildID]);
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
