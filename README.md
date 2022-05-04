# Scan Action Logs

[![.github/workflows/main.yml](https://github.com/JosiahSiegel/scan-action-log/actions/workflows/main.yml/badge.svg)](https://github.com/JosiahSiegel/scan-action-log/actions/workflows/main.yml)

Leverage [git-secrets](https://github.com/awslabs/git-secrets) to identify potential leaks in GitHub action logs.

 * Common Azure and Google Cloud patterns are available, thanks to fork [msalemcode/git-secrets](https://github.com/msalemcode/git-secrets).


## Inputs
```yml
  github-token:
    description: 'Token used to login to GitHub'
    required: true
  repo:
    description: 'Repo to scan run logs for exceptions'
    required: true
  run-limit:
    description: 'Limit on how many runs to scan'
    required: true
    default: '50'
```

## Outputs
```yml
  exceptions:
    description: 'json output of run logs with exceptions'
```

## Usage
```yml
      - name: Scan run logs
        uses: josiahsiegel/scan-action-logs@v1
        id: scan
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          repo: ${{ secrets.SCAN_REPO }}
          run-limit: '50'
      - name: Get scan exceptions
        run: echo "${{ steps.scan.outputs.exceptions }}"
```

## Run locally

```sh
docker build -t scan .
docker run scan "<GITHUB PERSONAL ACCESS TOKEN>" "<REPO NAME>" "<RUN SCAN LIMIT>"
```