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
const installer = __importStar(require("./installer"));
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        const APIEndpoint = "https://api.valar.dev/v1";
        const APIToken = core.getInput('token', { required: true });
        try {
            yield installer.installValar();
            core.debug("Submitting build to Valar ...");
            // Wait for build ID
            let buildID = '';
            yield exec.exec('valar', ['--api-token', APIToken, '--api-endpoint', APIEndpoint, 'push'], {
                listeners: {
                    stdout: (data) => {
                        buildID += data.toString();
                    },
                    stderr: (data) => { }
                }
            });
            core.debug("Submitted build with ID " + buildID);
            // Follow build logs
            yield exec.exec('valar', ['builds', 'logs', '-f', buildID]);
            core.debug("Build finished.");
        }
        catch (error) {
            core.setFailed(error.message);
        }
    });
}
run();
