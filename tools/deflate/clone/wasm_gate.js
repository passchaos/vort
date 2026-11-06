#!/usr/bin/env node
"use strict";

// Run every supplied WASI command and emit one aggregate JSON receipt.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const crypto = require("node:crypto");

// Keep the command's output machine readable while retaining other warnings.
const emitWarning = process.emitWarning;
process.emitWarning = function (warning, ...options) {
    const message = typeof warning === "string" ? warning : warning.message;
    if (message.startsWith("WASI is an experimental feature")) return;
    return emitWarning.call(this, warning, ...options);
};
const { WASI } = require("node:wasi");
process.emitWarning = emitWarning;

const usage = "node wasm_gate.js [--output report.json] [--work-dir DIR --config config.json] artifact1.wasm artifact2.wasm ...";

function requireCondition(condition, message) {
    if (!condition) throw new Error(message);
}

function sha256(bytes) {
    return crypto.createHash("sha256").update(bytes).digest("hex");
}

function argumentsFor(argv) {
    const options = { artifacts: [] };
    for (let index = 0; index < argv.length; index++) {
        const argument = argv[index];
        if (argument === "--help") return { help: true, artifacts: [] };
        if (["--output", "--work-dir", "--config"].includes(argument)) {
            requireCondition(index + 1 < argv.length, `missing value for ${argument}`);
            const key = argument.slice(2).replaceAll("-", "_");
            requireCondition(options[key] === undefined, `duplicate option ${argument}`);
            options[key] = argv[++index];
        } else {
            requireCondition(!argument.startsWith("--"), `unknown option ${argument}`);
            options.artifacts.push(argument);
        }
    }
    requireCondition(options.artifacts.length > 0, usage);
    requireCondition(!options.config || options.work_dir, "--config requires --work-dir");
    return options;
}

function configurationFor(options) {
    const configuration = { preopens: {}, config_path: null, config_argument: null };
    if (options.work_dir) {
        configuration.work_dir = fs.realpathSync(options.work_dir);
        requireCondition(fs.statSync(configuration.work_dir).isDirectory(), "--work-dir is not a directory");
        configuration.preopens["/work"] = configuration.work_dir;
    }
    if (options.config) {
        const configPath = path.isAbsolute(options.config) ? options.config : path.join(configuration.work_dir, options.config);
        configuration.config_path = fs.realpathSync(configPath);
        const relative = path.relative(configuration.work_dir, configuration.config_path);
        requireCondition(relative && relative !== ".." && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative),
            "--config must be a file inside --work-dir");
        requireCondition(fs.statSync(configuration.config_path).isFile(), "--config is not a file");
        configuration.config_argument = `/work/${relative.split(path.sep).join("/")}`;
    }
    return configuration;
}

function logReceipt(filename, failed) {
    const bytes = fs.readFileSync(filename);
    const result = { size: bytes.length, sha256: sha256(bytes) };
    if (failed && bytes.length) result.utf8_tail = bytes.subarray(-4096).toString("utf8");
    return result;
}

function runArtifact(artifact, configuration) {
    const result = { requested_path: artifact, status: "failed", execution_started: false,
        actual_exit_code: null, node_version: process.version };
    let temporary = null;
    const descriptors = [];
    try {
        result.wasm_path = fs.realpathSync(artifact);
        const bytes = fs.readFileSync(result.wasm_path);
        result.wasm_sha256 = sha256(bytes);
        result.wasm_size = bytes.length;
        const compiled = new WebAssembly.Module(bytes);
        result.imports = WebAssembly.Module.imports(compiled);
        result.imports_valid = result.imports.every(entry => entry.module === "wasi_snapshot_preview1" && entry.kind === "function");
        requireCondition(result.imports_valid, "artifact imports must be wasi_snapshot_preview1 functions only");
        result.exports = WebAssembly.Module.exports(compiled);
        requireCondition(result.exports.some(entry => entry.name === "_start" && entry.kind === "function"), "artifact lacks a function _start export");
        result.wasi_args = [result.wasm_path];
        if (configuration.config_argument) result.wasi_args.push(configuration.config_argument);
        temporary = fs.mkdtempSync(path.join(os.tmpdir(), "vort-clone-wasi-"));
        const stdout = fs.openSync(path.join(temporary, "stdout"), "w");
        descriptors.push(stdout);
        const stderr = fs.openSync(path.join(temporary, "stderr"), "w");
        descriptors.push(stderr);
        const wasi = new WASI({ version: "preview1", args: result.wasi_args, env: {},
            preopens: configuration.preopens, returnOnExit: true, stdout, stderr });
        const instance = new WebAssembly.Instance(compiled, { wasi_snapshot_preview1: wasi.wasiImport });
        requireCondition(typeof instance.exports._start === "function", "instantiated _start is not a function");
        result.execution_started = true;
        result.actual_exit_code = wasi.start(instance);
        requireCondition(result.actual_exit_code === 0, `wasi.start returned ${result.actual_exit_code}`);
        result.status = "ok";
    } catch (error) {
        result.error = `${error.name}: ${error.message}`;
    } finally {
        for (const descriptor of descriptors) fs.closeSync(descriptor);
        if (temporary) {
            for (const stream of ["stdout", "stderr"]) {
                const filename = path.join(temporary, stream);
                if (fs.existsSync(filename)) result[stream] = logReceipt(filename, result.status !== "ok");
            }
            fs.rmSync(temporary, { recursive: true, force: true });
        }
    }
    return result;
}

function main(argv) {
    let options;
    let report = { schema: "vort-deflate-clone-wasm-v1", utc: new Date().toISOString(),
        node_version: process.version, status: "failed", ok: false, artifacts: [] };
    try {
        options = argumentsFor(argv);
        if (options.help) {
            report = { schema: report.schema, status: "help", usage };
        } else {
            report.configuration = configurationFor(options);
            report.artifacts = options.artifacts.map(artifact => runArtifact(artifact, report.configuration));
            report.artifact_count = report.artifacts.length;
            report.ok = report.artifacts.every(artifact => artifact.status === "ok" && artifact.actual_exit_code === 0);
            report.status = report.ok ? "ok" : "failed";
            report.aggregate_exit_code = report.ok ? 0 : 1;
        }
        if (options.output) {
            const destination = path.resolve(options.output);
            fs.mkdirSync(path.dirname(destination), { recursive: true });
            fs.writeFileSync(destination, JSON.stringify(report) + "\n");
        }
    } catch (error) {
        report.status = "failed";
        report.ok = false;
        report.aggregate_exit_code = 1;
        report.error = `${error.name}: ${error.message}`;
    }
    process.stdout.write(JSON.stringify(report) + "\n");
    process.exitCode = report.status === "help" || report.ok ? 0 : 1;
}

if (require.main === module) main(process.argv.slice(2));
