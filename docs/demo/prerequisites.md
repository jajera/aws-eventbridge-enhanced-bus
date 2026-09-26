# Prerequisites

Install and version-check tooling before the first deploy.

## Tools and access

| Requirement | Detail |
| --- | --- |
| AWS CLI v2 | **≥ 2.37.3** (`aws eventsv2`) |
| Python 3 | **3.14** (packaging + Lambda `python3.14`) |
| Profiles | **`lab`** and **`dev`** — distinct accounts, same org (share is lab → dev) |
| Region | `ap-southeast-2` |
| Mutation gate | `export EB_ENHANCED_ALLOW_AWS=1` before **teardown** scripts |
| Live feed | Existing `iot_talk_*` events/telemetry rules in **lab** (devices + fleet); Verify can also smoke with CLI `put-events` |

### Install AWS CLI v2

Official
[install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
Require **≥ 2.37.3** (this lab uses **2.37.4**).

=== "Install script (latest)"

    ```bash
    curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
    aws --version
    ```

=== "User-local"

    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/aws-cli"
    ./aws/install \
      --bin-dir "$HOME/.local/bin" \
      --install-dir "$HOME/.local/share/aws-cli" \
      --update
    export PATH="$HOME/.local/bin:$PATH"
    aws --version
    ```

    Keep `$HOME/.local/bin` ahead on `PATH`. On ARM use
    `awscli-exe-linux-aarch64.zip`.

=== "System-wide update"

    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install --update
    hash -r
    aws --version
    ```

### Confirm the version

<div class="run" markdown>

```bash
which aws
aws --version
```

```text {.no-copy}
~/.local/bin/aws
aws-cli/2.37.4 Python/3.14.6 Linux/7.0.0-30-generic exe/x86_64.ubuntu.24
```

</div>

<div class="run" markdown>

```bash
python3 - <<'PY'
import subprocess
v = subprocess.check_output(["aws", "--version"], text=True)
ver = v.split("/")[1].split(" ")[0]
maj, minor, patch = (int(x) for x in ver.split(".")[:3])
assert (maj, minor, patch) >= (2, 37, 3), v
print("ok:", v.strip())
PY
aws eventsv2 help >/dev/null && echo eventsv2_ok
python3 --version
```

```text {.no-copy}
ok: aws-cli/2.37.4 Python/3.14.6 Linux/7.0.0-30-generic exe/x86_64.ubuntu.24
eventsv2_ok
Python 3.14.6
```

</div>

!!! note "`eventsv2`"
    CLI **2.37.2** introduced `aws eventbridgev2`; **2.37.3** renamed it to
    `aws eventsv2`. Prefer `eventsv2`. Tear-down helpers in `scripts/lib.sh`
    accept either name via `eb_cli`.

## Mutation gate

**Tear-down scripts** refuse to change AWS unless `EB_ENHANCED_ALLOW_AWS=1` is
set. Deploy and Verify are plain AWS CLI in the Demo pages (no deploy scripts).
Read-only helpers (`capture-accounts.sh`) do not need the gate.

Set it in the same shell as the profile when tearing down:

<div class="run" markdown>

```bash
export AWS_PROFILE=lab AWS_REGION=ap-southeast-2 EB_ENHANCED_ALLOW_AWS=1
```

```text {.no-copy}
(no output)
```

</div>

!!! warning "Unset gate"
    Without it, teardown scripts stop with `Refusing to mutate AWS` and change
    nothing — a deliberate guard, not an error.

Next: [Check profiles](profiles.md).

## References

- [Installing or updating the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS CLI install script](https://awscli.amazonaws.com/v2/install.sh)
