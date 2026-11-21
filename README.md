# <img src="https://user-images.githubusercontent.com/3391295/95904392-bd2d0880-0d97-11eb-9ba8-c4e1b55dcc39.png" alt="action" height="30">

This action builds and deploys a service on [Valar](https://valar.dev). It waits until the deployment is live, fails the job if the build or the deployment fails, and reports the service's URL. It can also deploy a preview of every pull request.

It runs on Linux and macOS runners (x64 and ARM64) and needs nothing but `curl` and `bash`.

## Deploy on every push

```yaml
name: Deploy
on:
  push:
    branches: [main]

concurrency:
  group: valar-deploy
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    environment:
      name: production
      url: ${{ steps.valar.outputs.url }}
    steps:
      - uses: actions/checkout@v7
      - id: valar
        uses: valar/action@v3
```

The project, service and build settings come from `.valar.yml`, which `valar service init` writes. The build log appears in the job log. The URL appears in the job summary and, through `environment.url`, on the commit and its pull request. The `concurrency` group lets one deploy finish before the next starts.

## Deploy without a stored token

Without a `token` input, the action exchanges the job's GitHub identity token for a Valar token that acts as whoever added the trust policy, can only read and deploy the one service, and lasts an hour. The job needs `permissions: id-token: write`, and the project needs a trust policy that admits the job. Someone who manages the project adds it once, with the [Valar CLI](https://github.com/valar/cli) and a token created in the console, here for the workflow above saved as `.github/workflows/deploy.yml`:

```bash
valar trust add --project acme --service web \
  --github-repo acme/web --environment production --workflow deploy.yml
```

The policy pins the repository's and its owner's IDs, the workflow file and the `push` event, so other repositories, workflows and triggers do not match. A job that names an environment, like the one above, gets an identity token for the environment rather than the branch: protect the environment with deployment branch rules (Settings, Environments, production, Deployment branches), because GitHub issues that identity token to every job that names the environment, whatever its branch. A job without an environment needs `--branch main` in place of `--environment production`.

`valar trust list` shows a project's policies and `valar trust remove <id>` deletes one and revokes the tokens it issued. When no policy admits a job, the step fails and its log shows the identity token's claims to compare with `valar trust list`.

The installation must trust GitHub's identity tokens; on a self-hosted one, its operator sets this up. Without that, or to deploy from other CI systems, give the action a stored token instead:

```yaml
      - uses: valar/action@v3
        with:
          token: ${{ secrets.VALAR_TOKEN }}
```

Create the token bound to the project with only `read` and `deploy`, `valar token create github-deploy --project acme --scopes read,deploy`, and store it as a repository or environment secret. It lasts 90 days by default; the job needs no `id-token` permission then.

## Inputs

| Input | Default | |
|---|---|---|
| `token` | | Valar API token that can only read and deploy in the project (`valar token create --project <project> --scopes read,deploy github-deploy`), stored as a secret. Without it, the action exchanges the job's GitHub identity token under a trust policy, which needs `permissions: id-token: write`. |
| `audience` | the endpoint's origin | Audience of that identity token, such as `https://api.valar.dev`. Set it only if the installation's operator configured another one. |
| `endpoint` | `https://api.valar.dev/v2` | API of the Valar installation, for self-hosted Valar. |
| `project` | from `.valar.yml` | Project to deploy to. |
| `service` | from `.valar.yml` | Service to deploy. |
| `workdir` | `.` | Directory to push. `.valar.yml` is looked up from here upwards. |
| `wait` | `true` | Wait for the build and the deployment, and fail if either fails. With `false` the step ends once the build is submitted. |
| `deploy` | `true` | With `false` the service is only built, for example to check pull requests. |
| `preview` | `false` | Deploy pull request previews, see below. |
| `github-token` | `github.token` | Token for the preview comment. |
| `timeout` | `30m` | How long to wait for the build and the deployment together. |
| `cli-version` | `4.10.0` | [Valar CLI](https://github.com/valar/cli) release to run. The default release's binaries are verified against checksums in this action. |

## Outputs

| Output | |
|---|---|
| `build-id` | ID of the build. |
| `service` | Service that was deployed, when it was given as an input or is a preview. |
| `url` | Preferred URL of the service: a linked custom domain if there is one, else its own `<project>-<service>` domain. Empty without a deployment. |

## Pull request previews

With `preview: true`, a `pull_request` run deploys to the service `<service>pr<number>` instead, for example `webpr42`, and comments its URL on the pull request. The number comes from the run's ref, `refs/pull/<number>/merge`. When the pull request closes, the preview is disabled; when it reopens, it is enabled and deployed again.

```yaml
name: Preview
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

concurrency:
  group: valar-preview-${{ github.event.pull_request.number }}

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        if: github.event.action != 'closed'
      - uses: valar/action@v3
        with:
          project: acme
          service: web
          preview: true
```

The trust policy for previews names the prefix followed by `*`; each pull request may then deploy only its own preview:

```bash
valar trust add --project acme --service 'webpr*' --github-repo acme/web --pull-requests
```

* Name the project and service in the inputs, because a closed pull request's run has no checkout to read `.valar.yml` from.
* The action skips pull requests from forks, but don't rely on that check: it runs in the pull request's own copy of the workflow, which a fork can change. Public repositories give fork pull requests no secrets and no identity tokens. A private repository can give them both, through "Send write tokens to workflows from pull requests" and "Send secrets to workflows from pull requests" in its Actions settings. Then a stored token reaches the fork's code. What bounds an identity token is the trust policy: a preview policy admits a pull request only to its own `<service>pr<number>`, and a branch or environment policy pins the subject, the `push` event and the workflow's ref, while a pull request's job carries the `pull_request` event and the pull request's ref.
* Use `pull_request`, never `pull_request_target`, which would deploy a fork's code with your credentials. Without a `token`, the action refuses to exchange identity tokens in `pull_request_target` and `workflow_run` runs.
* Disabled previews stop running and answer 503. Valar can't delete services yet, so they remain in `valar service list`.
* Anyone who can push a branch to the repository can deploy a preview. Under a trust policy, it reaches only `<service>pr<number>` and runs as that preview's own service account. With a stored token, it holds the same token as production deploys; keep previews in a project of their own if that matters.

## Check that pull requests build

```yaml
on: pull_request
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: valar/action@v3
        with:
          token: ${{ secrets.VALAR_TOKEN }}
          deploy: false
```

This check keeps a stored token: a trust policy that admitted pull requests to the service itself would let any of them deploy it, since `deploy: false` is only an input.

## Several services in one repository

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        dir: [api, web]
    steps:
      - uses: actions/checkout@v7
      - uses: valar/action@v3
        with:
          token: ${{ secrets.VALAR_TOKEN }}
          workdir: ${{ matrix.dir }}
```

Without a stored token, each service needs a trust policy of its own.

## Self-hosted Valar

Set `endpoint` to your installation's API, such as `https://api.example.com/v2`. Without a `token`, the identity token is requested for the endpoint's origin, `https://api.example.com`, unless `audience` names another.

## Pinning

To run exactly the code you reviewed, pin the action to a commit:

```yaml
- uses: valar/action@<commit sha> # v3.0.0
```

## Upgrading from v2

v2 ran the Valar CLI 2.0.1, always against `api.valar.dev`, and finished as soon as the build was submitted, so failed builds left the job green. v3 takes the same `token` and `workdir` inputs. It waits for the deployment by default; set `wait: false` for the old behaviour.

## License

Apache-2.0
