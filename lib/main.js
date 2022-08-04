"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = __importStar(require("@actions/core"));
const exec = __importStar(require("@actions/exec"));
const installer = __importStar(require("./installer"));
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        const APIEndpoint = "https://api.valar.dev/v2";
        const APIToken = core.getInput('token', { required: true });
        const Workdir = core.getInput('workdir', { required: false });
        try {
            yield installer.installValar();
            core.exportVariable("VALAR_TOKEN", APIToken);
            core.exportVariable("VALAR_ENDPOINT", APIEndpoint);
            core.debug("Submitting build to Valar ...");
            // Wait for build ID
            const options = {
                listeners: {
                    stdout: (data) => {
                        output += data.toString();
                    },
                    stderr: (data) => { }
                }
            };
            if (Workdir) {
                options.cwd = Workdir;
            }
            let output = '';
            yield exec.exec('valar', ['push'], options);
            let buildID = output.trim();
            console.log("Submitted build with ID " + buildID);
        }
        catch (error) {
            let message;
            if (error instanceof Error)
                message = error.message;
            else
                message = String(error);
            core.setFailed(message);
        }
    });
}
run();
