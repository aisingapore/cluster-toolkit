# a3-highgpu-8g + GCSFuse/LSSD (Slurm)

This example provisions a Slurm cluster on **`a3-highgpu-8g`** (8× NVIDIA H100
80GB) with GPUDirect-**TCPX** networking, and mounts a Cloud Storage bucket via
**GCSFuse** with **Local SSD (LSSD)** caching, using purpose-built mount
profiles for checkpointing, training-data reads, and model serving.

It was produced by combining two existing Cluster Toolkit examples:

- the **`a3-highgpu-8g`** base blueprint (correct a3-high hardware + TCPX
  networking + image build), and
- the GCSFuse/LSSD storage pattern from **`a2-ultragpu-8g-fuse`**.

This document explains how the Toolkit's storage integration evolved
(`a3mega normal → a3mega fuse`), how `a2ultra fuse` adapted the idea, and how
those changes were carried over to build this `a3high fuse` example.

---

## 1. How Cluster Toolkit composes a cluster

A **blueprint** (`*.yaml`) is expanded by `gcluster` into Terraform (and Packer)
and then deployed. The moving parts:

| Concept | Meaning |
|---|---|
| `vars` | Global variables, referenced elsewhere as `$(vars.NAME)`. |
| `deployment_groups` | Ordered stages (e.g. build image → build cluster). Each becomes its own Terraform/Packer working directory. |
| `modules` | Reusable units (`id`, `source`, `settings`). Wired together with `use: [...]` and `$(module_id.output)` references. |
| Deployment file (`*-deployment.yaml`) | Per-environment overrides — `project_id`, `region`, the Terraform state `bucket`, reservation, cluster size, etc. Merged into `vars` at expand time. |

Storage is "just another module." That is why the same cluster can be shipped
with different storage backends by swapping/adding a handful of modules — which
is exactly what the variants below do.

---

## 2. The storage lineage

### 2a. `a3mega normal` (base) — Managed Lustre

`a3-megagpu-8g/a3mega-slurm-blueprint.yaml` uses **Managed Lustre** as the
high-throughput shared filesystem:

```yaml
vars:
  lustre_instance_id: $(vars.deployment_name)-lustre
  lustre_size_gib: 36000
  per_unit_storage_throughput: 500
```

Lustre gives a POSIX, high-bandwidth scratch/dataset filesystem, but it is a
provisioned (and billed) instance sized up-front.

### 2b. `a3mega fuse` (`a3mega-slurm-gcsfuse-lssd-blueprint.yaml`)

The `-gcsfuse-lssd` variant **removes Lustre** and instead mounts a GCS bucket
with GCSFuse, caching on Local SSD. It does this with the **ansible + systemd**
pattern: reusable runner lists are defined as `vars` and installed by the
startup scripts.

```yaml
vars:
  gcs_bucket: ""
  gcsfuse_lssd_runners:            # <- becomes a systemd gcsfuse.service
  - type: ansible-local
    destination: gcsfuse.yml
    content: |
      ...
      ExecStart=gcsfuse --config-file /etc/gcsfuse.yml $(vars.gcs_bucket) /gcs
```

It writes `/etc/gcsfuse.yml` (file cache on `$(vars.localssd_mountpoint)`,
parallel downloads) and a read-only variant `/etc/gcsfuse-ro.yml`, then wires
them into the node startup via `runners: $(flatten([vars.a3m_runners,
vars.gcsfuse_lssd_runners]))`.

**Takeaway:** going `normal → fuse` = swap a provisioned Lustre filesystem for
GCS-backed storage that is cheap at rest and accelerated by LSSD caching.

### 2c. `a2ultra fuse` (`a2-ultragpu-8g-fuse/ml-slurm-gcsfuse-lssd.yaml`)

`a2ultra fuse` reaches the same goal (GCS + LSSD) but with a cleaner,
**module-driven** pattern instead of hand-written ansible/systemd. Two Toolkit
modules do the work:

- `modules/file-system/cloud-storage-bucket` — creates the bucket (with
  Hierarchical Namespace) and defines the base `/gcs` mount.
- `modules/file-system/pre-existing-network-storage` (with `fs_type: gcsfuse`) —
  defines additional mount-points, each tuned with a GCSFuse **profile**.

```yaml
- id: gcs_checkpoints
  source: modules/file-system/pre-existing-network-storage
  settings:
    remote_mount: $(gcs_bucket.gcs_bucket_name)
    local_mount: /gcs-checkpoints
    fs_type: gcsfuse
    mount_options: "profile=aiml-checkpointing,\
      cache_dir=$(vars.localssd_mountpoint),..."
```

Three purpose-built mounts are created:

| Mount | Profile | Optimized for |
|---|---|---|
| `/gcs-checkpoints` | `aiml-checkpointing` | Large sequential checkpoint writes/reads |
| `/gcs-training-data` | `aiml-training` | Cached random reads of training data |
| `/gcs-model-serving` | `aiml-serving` | Read-heavy serving |

Each module emits `client_install_runner` and `mount_runner` outputs, which are
wired straight into the node startup script:

```yaml
runners:
- $(gcs_checkpoints.client_install_runner)
- $(gcs_checkpoints.mount_runner)
- ...
```

**Why this is nicer than 2b:** no bespoke systemd units to maintain; mount
tuning is declarative via named profiles; the bucket is created and referenced
by module output rather than a free-form `gcs_bucket` string.

> Note: while adapting `a2ultra fuse` in this repo, both its files had lost all
> YAML indentation (and the embedded shell/Python scripts had lost their own
> indentation and had broken line-continuations). They were reconstructed to
> valid YAML — the *structure* above is the intended design.

### The two GCSFuse patterns, side by side

| | `a3mega fuse` (2b) | `a2ultra fuse` / `a3high fuse` (2c) |
|---|---|---|
| Mechanism | ansible-local runners + systemd services | Toolkit file-system modules |
| Bucket | pre-existing string `vars.gcs_bucket` | created by `cloud-storage-bucket` |
| Mount tuning | hand-written `/etc/gcsfuse*.yml` | `profile=aiml-*` mount options |
| Mount-points | `/gcs`, `/gcs-ro` | `/gcs` + `/gcs-checkpoints`, `/gcs-training-data`, `/gcs-model-serving` |
| Wiring | `flatten([...runners])` | `$(mod.client_install_runner)` / `$(mod.mount_runner)` |

---

## 3. How this `a3high fuse` example was built

### 3a. Why not "just change the machine type"

The a2 blueprint has **no concept of GPUDirect networking**. `a3-highgpu-8g`
needs a substantial, hardware-specific stack that A2 does not:

- 4× GPU VPCs (`modules/network/multivpc`, `network_count: 4`)
- a **TCPX-patched kernel** installed from a private PPA at image-build time
- a `gpu_rxq_configuration.textproto` describing GPU↔NIC queue mapping
- an **RxDM** receive-data-path-manager prolog/epilog on the partition
- a `delay-a3.service` so boot waits until all NICs are routable
- `on_host_maintenance: TERMINATE`, `CoresPerSocket: 52`, `compute_sa`

So the base had to be the **working a3-high blueprint**, not the a2 one. This
mirrors how the Toolkit itself ships `a3mega-slurm` and
`a3mega-slurm-gcsfuse-lssd` as base + storage-variant.

### 3b. What was kept from the a3-high base (unchanged)

Everything a3-high-specific: `sysnet` + `gpunets`, the entire `build-script`
group (TCPX kernel, GCC 12, NVIDIA/DCGM packages, `delay-a3`, gpu_rxq config,
kernel cleanup), the Ubuntu-based Packer image build, `homefs` Filestore for
`/home`, `compute_sa`, the `a3_nodeset`/`a3_partition`, and the controller/login
setup with RxDM prolog/epilog. The image build already installs GCSFuse via
`"install_gcsfuse": true` in `/var/tmp/slurm_vars.json`.

### 3c. What was grafted in from `a2ultra fuse` (the module-based 2c pattern)

Exact changes applied on top of `a3high-slurm-blueprint.yaml`:

1. **Renamed** the blueprint: `a3high-slurm` → `a3high-slurm-gcsfuse-lssd`.
2. **Added four modules** to the `cluster` group (after `compute_sa`):
   `gcs_bucket` (cloud-storage-bucket, HNS, `/gcs`) plus `gcs_checkpoints`,
   `gcs_training_data`, `gcs_model_serving` (pre-existing-network-storage,
   `fs_type: gcsfuse`, `aiml-*` profiles, `cache_dir` on the LSSD mountpoint).
3. **Wired the mount runners** into `a3_startup.settings.runners` — the six
   `client_install_runner` / `mount_runner` outputs are prepended before the
   existing DCGM ansible runner, so compute nodes mount the buckets on boot.
4. **Added `gcs_bucket` to `slurm_controller.use`** so the base `/gcs` mount is
   propagated cluster-wide via Slurm network storage.

`localssd_mountpoint: /mnt/localssd` already existed in the a3-high `vars` and is
reused as the GCSFuse cache dir; the existing `local_ssd_filesystem` block in
`a3_startup` provisions that LSSD scratch space.

The result was validated with `gcluster expand` — it expands cleanly (the only
gate is the runtime `test_reservation_exists` validator, which needs a real
reservation).

---

## 4. Deploy

### Required deployment variables

`a3high-slurm-gcsfuse-lssd-deployment.yaml` — pre-filled vs. supply-yourself:

**Pre-filled** (adjust if needed): Terraform state `bucket`, `project_id`,
`deployment_name`, `slurm_cluster_name`, `a3_partition_name`, `enable_slurm_auth`,
and the shared TCPX PPA credentials.

**You must supply:**

- `region` / `zone` — must have `a3-highgpu-8g` capacity in your reservation
- `a3_reservation_name` — a3-high **requires** a reservation (or set
  `a3_dws_flex_enabled: true` **or** `a3_enable_spot_vm: true` — pick one)
- `a3_static_cluster_size` — number of a3-high nodes

> The TCPX kernel credentials (`tcpx_kernel_login`, `tcpx_kernel_password`,
> `keyserver_ubuntu_key`) are **shared values provided by Google Cloud staff for
> the private TCPX kernel PPA** — they are not user/project specific. Without
> them the image build fails to install the TCPX-patched kernel.

### Command

```bash
./gcluster deploy \
  examples/machine-learning/a3-highgpu-8g-fuse/a3high-slurm-gcsfuse-lssd.yaml \
  -d examples/machine-learning/a3-highgpu-8g-fuse/a3high-slurm-gcsfuse-lssd-deployment.yaml \
  --auto-approve -w
```

The `image` group builds the Packer image first (~15–30 min) before the cluster
is created.

---

## 5. Caveats

- **GCSFuse profiles need a recent GCSFuse.** The `profile=aiml-*` mount options
  require a modern GCSFuse. The image installs GCSFuse via slurm-gcp; if a
  profile is unrecognized at mount time, bump the GCSFuse version in the image
  build. (Same consideration applies to `a2ultra fuse`.)
- **Reservation / capacity.** a3-highgpu-8g is capacity-constrained; the deploy
  will fail to bring up nodes without a matching reservation (or DWS Flex / Spot).
- **State bucket region** does not need to match the compute region; this example
  reuses the existing `gcp0626-a2u` bucket (a different `deployment_name` keeps
  the Terraform state under a separate prefix).
