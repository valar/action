import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as tc from '@actions/tool-cache';

/**
 * Install Valar.
 *
 * @param {string} version
 */
export async function installValar() {
    let arch = process.platform
    if (arch === 'linux') {
        let toolPath = tc.find('Valar', '1.0.0');

        if (toolPath) {
            core.debug(`Tool found in cache ${toolPath}`);
        } else {
            let url = "http://github.com/valar/cli/releases/v1.0.0/download/valar_linux_amd64";
            let path = await tc.downloadTool(url);
            await exec.exec('chmod', ['+x', path]);
            toolPath = await tc.cacheFile(path, 'valar', 'Valar', '1.0.0', arch);
        }
        core.addPath(toolPath);
    } else {
        throw new Error('@actions/valar-action only supports Ubuntu Linux at this time');
    }
}
