"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    result["default"] = mod;
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = __importStar(require("@actions/core"));
const exec = __importStar(require("@actions/exec"));
const tc = __importStar(require("@actions/tool-cache"));
/**
 * Install Valar.
 *
 * @param {string} version
 */
let toolVersion = '2.0.1';
function installValar() {
    return __awaiter(this, void 0, void 0, function* () {
        let arch = process.platform;
        if (arch === 'linux') {
            let toolPath = tc.find('valar', toolVersion);
            if (toolPath) {
                core.debug(`Tool found in cache ${toolPath}`);
            }
            else {
                let url = `https://github.com/valar/cli/releases/download/v${toolVersion}/valar_linux_amd64`;
                let path = yield tc.downloadTool(url);
                yield exec.exec('chmod', ['+x', path]);
                toolPath = yield tc.cacheFile(path, 'valar', 'valar', toolVersion, arch);
            }
            core.addPath(toolPath);
        }
        else {
            throw new Error('valar/action only supports Ubuntu Linux at this time');
        }
    });
}
exports.installValar = installValar;
