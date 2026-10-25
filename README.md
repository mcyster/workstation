# Workstation

A persistent development machine on Google Compute Engine, controlled from GitHub Actions or a local CLI. Use it through SSH or a browser editor. The environment is independent of any repository or agent.

## Use

In GitHub, open **Actions → Workstation → Run workflow** to create, start, stop, rotate a browser password, or destroy a workstation. The run summary links to the browser editor and its password in Google Cloud Secret Manager.

Or run locally with an authenticated Google Cloud CLI:

```sh
scripts/e-workstation create main --web-terminal
scripts/e-workstation list
scripts/e-workstation shell main
scripts/e-workstation stop main
scripts/e-workstation start main
scripts/e-workstation web-terminal main
scripts/e-workstation destroy main
```

## Set up

1. Create a billed Google Cloud project and authenticate `gcloud`.
2. Run `bash infra/workstation/gcloud-identity --project PROJECT --repo mcyster/workstation`.
3. Set Actions variable `WORKSTATION_GCLOUD_PROJECT` and secrets `WORKSTATION_GCLOUD_SERVICE_ACCOUNT` and `WORKSTATION_GCLOUD_WORKLOAD_IDENTITY_PROVIDER` from the output. Optionally set `WORKSTATION_GCLOUD_ZONE`.
4. Run the **Workstation** action.

The persistent disk survives stop/start and continues to incur storage charges. Destroy deletes the disk. There are no automatic backups.

See [docs/workstation.md](docs/workstation.md) for details.
