import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as tc from '@actions/tool-cache';

/**
 * Install Valar.
 *
 * @param {string} version
 */

let toolVersion = '1.0.1';

export async function installValar() {
    let arch = process.platform
    if (arch === 'linux') {
        let toolPath = tc.find('valar', toolVersion);

        if (toolPath) {
            core.debug(`Tool found in cache ${toolPath}`);
        } else {
            let url = `https://github.com/valar/cli/releases/download/v${toolVersion}/valar_linux_amd64`;
            let path = await tc.downloadTool(url);
            await exec.exec('chmod', ['+x', path]);
            toolPath = await tc.cacheFile(path, 'valar', 'valar', toolVersion, arch);
        }
        core.addPath(toolPath);
    } else {
        throw new Error('valar/action only supports Ubuntu Linux at this time');
    }
}
