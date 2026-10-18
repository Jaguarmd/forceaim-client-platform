import { cp, mkdir, rm } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = fileURLToPath(new URL(".", import.meta.url));
const output = resolve(projectRoot, "dist");
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await Promise.all(["index.html", "favicon.svg"].map((file) => cp(resolve(projectRoot, file), resolve(output, file))));
console.log("Built the standalone ForceAim client platform into dist/.");
