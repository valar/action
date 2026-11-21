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
    environment:
      name: production
      url: ${{ steps.valar.outputs.url }}
    steps:
      - uses: actions/checkout@v7
      - id: valar
        uses: valar/action@v3
        with:
          token: ${{ secrets.VALAR_TOKEN }}
```

The project, service and build settings come from `.valar.yml`, which `valar service init` writes. The build log appears in the job log. The URL appears in the job summary and, through `environment.url`, on the commit and its pull request. The `concurrency` group lets one deploy finish before the next starts.

## Inputs

| Input | Default | |
|---|---|---|
| `token` | | Valar API token. Store it as a repository or environment secret. |
| `endpoint` | `https://api.valar.dev/v2` | API of the Valar installation, for self-hosted Valar. |
| `project` | from `.valar.yml` | Project to deploy to. |
| `service` | from `.valar.yml` | Service to deploy. |
| `workdir` | `.` | Directory to push. `.valar.yml` is looked up from here upwards. |
| `wait` | `true` | Wait for the build and the deployment, and fail if either fails. With `false` the step ends once the build is submitted. |
| `deploy` | `true` | With `false` the service is only built, for example to check pull requests. |
| `preview` | `false` | Deploy pull request previews, see below. |
| `github-token` | `github.token` | Token for the preview comment. |
| `timeout` | `30m` | How long to wait for the build and the deployment together. |
| `cli-version` | `4.9.0` | [Valar CLI](https://github.com/valar/cli) release to run. The default release's binaries are verified against checksums in this action. |

## Outputs

| Output | |
|---|---|
| `build-id` | ID of the build. |
| `service` | Service that was deployed, when it was given as an input or is a preview. |
| `url` | Preferred URL of the service: a linked custom domain if there is one, else its own `<project>-<service>` domain. Empty without a deployment. |

## Pull request previews

With `preview: true`, a `pull_request` run deploys to the service `<service>pr<number>` instead, for example `webpr42`, and comments its URL on the pull request. When the pull request closes, the preview is disabled; when it reopens, it is enabled and deployed again.

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

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        if: github.event.action != 'closed'
      - uses: valar/action@v3
        with:
          token: ${{ secrets.VALAR_TOKEN }}
          project: acme
          service: web
          preview: true
```

* Name the project and service in the inputs, because a closed pull request's run has no checkout to read `.valar.yml` from.
* Pull requests from forks get no preview: their runs have no access to secrets.
* Use `pull_request`, never `pull_request_target`, which would deploy a fork's code with your token.
* Disabled previews stop running and answer 503. Valar can't delete services yet, so they remain in `valar service list`.
* Anyone who can push a branch to the repository can deploy a preview, with the same token as production deploys. Keep previews in a project of their own if that matters.

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

## Self-hosted Valar

Set `endpoint` to your installation's API, such as `https://api.example.com/v2`.

## Pinning

To run exactly the code you reviewed, pin the action to a commit:

```yaml
- uses: valar/action@<commit sha> # v3.0.0
```

## Upgrading from v2

v2 ran the Valar CLI 2.0.1, always against `api.valar.dev`, and finished as soon as the build was submitted, so failed builds left the job green. v3 takes the same `token` and `workdir` inputs. It waits for the deployment by default; set `wait: false` for the old behaviour.

## License

Apache-2.0
