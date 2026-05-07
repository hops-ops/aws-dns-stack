# aws-dns-stack

Deploys ExternalDNS + Route53 hosted zones, plus an optional cert-manager **integration** (a Let's Encrypt DNS-01 ClusterIssuer wired to the hosted zones, and a deletion-ordering Usage). cert-manager itself is installed separately — typically via [aws-cert-stack](https://github.com/hops-ops/aws-cert-stack).

## Why DNSStack?

**Without DNSStack:**
- Manual DNS record management for every service endpoint
- Manual ClusterIssuer wiring per cluster, per hosted zone
- Separate IAM roles, policies, and Helm releases to coordinate
- Easy to misconfigure DNS-01 solvers or forget to wire hosted zone IDs

**With DNSStack:**
- Single claim provisions Route53 zones, ExternalDNS, and (optionally) the ClusterIssuer
- Automatic DNS record creation for Kubernetes Services and Ingresses
- Hosted zone IDs automatically wired into ClusterIssuer DNS-01 solvers
- Deletion-ordering Usage prevents the ClusterIssuer from outliving the cert-manager Release

## cert-manager integration

`spec.certManager.enabled` (default `true`) controls whether this stack composes the cert-manager integration:

- `true` — render the ClusterIssuer + protection Usage. Assumes cert-manager is already installed on the cluster (e.g. via [aws-cert-stack](https://github.com/hops-ops/aws-cert-stack)).
- `false` — skip the integration entirely. Use this on clusters without cert-manager, or where the DNS-01 ClusterIssuer is provided some other way.

This stack does **not** install cert-manager. It only composes the integration glue once cert-manager is available.

The Usage references the cert-manager Helm Release by name. Default: `cert-manager` (matches aws-cert-stack's `spec.releaseName` default). Override via `spec.certManager.name` if your Release has a different name. If cert-manager isn't Crossplane-managed (e.g. installed via raw `helm install`), the Usage will reference a non-existent resource and won't reach Ready — install cert-manager via aws-cert-stack (or another Crossplane-managed path) for the ordering guarantee.

## The Journey

### Stage 1: Getting Started

Minimal configuration for a single domain.

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: DNSStack
metadata:
  name: dns
  namespace: default
spec:
  clusterName: my-cluster
  aws:
    region: us-east-1
  domains:
  - name: example.com
  clusterIssuer:
    email: admin@example.com
```

Assumes cert-manager is installed (e.g. via aws-cert-stack). Composes:
- A Route53 hosted zone for `example.com`
- ExternalDNS watching for DNS annotations on Services/Ingresses
- A ClusterIssuer using Let's Encrypt production with DNS-01 over Route53
- A Usage holding the cert-manager Release until the ClusterIssuer is gone

### Stage 2: Growing (Multiple Domains)

Add multiple domains and customize AWS settings.

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: DNSStack
metadata:
  name: dns
  namespace: default
spec:
  clusterName: prod-cluster
  aws:
    region: us-west-2
    permissionsBoundaryArn: arn:aws:iam::123456789012:policy/boundary
    rolePrefix: prod-
    tags:
      environment: production
  domains:
  - name: example.com
  - name: internal.example.com
  clusterIssuer:
    email: platform@example.com
```

### Stage 3: Import Existing

Adopt existing Route53 hosted zones without recreating them.

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: DNSStack
metadata:
  name: dns
  namespace: default
spec:
  clusterName: prod-cluster
  aws:
    region: us-west-2
  domains:
  - name: example.com
    externalName: Z1234567890ABC
  clusterIssuer:
    email: platform@example.com
```

### Stage 4: Skip the cert-manager integration

For clusters without cert-manager (or where the ClusterIssuer is provided elsewhere):

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: DNSStack
metadata:
  name: dns
  namespace: default
spec:
  clusterName: dev-cluster
  aws:
    region: us-east-1
  domains:
  - name: example.com
  certManager:
    enabled: false
```

## Status

```yaml
status:
  ready: true
  hostedZones:
  - domain: example.com
    zoneId: "Z1234567890ABC"
```

| Field | Description |
|-------|-------------|
| `ready` | Whether all components are ready |
| `hostedZones[].domain` | Domain name |
| `hostedZones[].zoneId` | Route53 hosted zone ID |

## Composed Resources

- `Route53 Zone` — one per domain in `spec.domains`
- `Helm Release (external-dns)` + `PodIdentity` — automatic DNS record management
- `Kubernetes Object (ClusterIssuer)` — Let's Encrypt ACME issuer with DNS-01 Route53 solver (only when `certManager.enabled: true`)
- `protection.Usage` — holds the external cert-manager Helm Release until the ClusterIssuer is deleted (only when `certManager.enabled: true`)

## Configuration Reference

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `clusterName` | Yes | - | Target cluster name |
| `aws.region` | Yes | - | AWS region |
| `aws.permissionsBoundaryArn` | No | - | IAM permissions boundary |
| `aws.rolePrefix` | No | - | Prefix for IAM role names |
| `aws.tags` | No | `{}` | Additional AWS tags |
| `domains[].name` | Yes | - | Domain name |
| `domains[].externalName` | No | - | Existing zone ID to import |
| `externalDNS.enabled` | No | `true` | Deploy ExternalDNS |
| `certManager.enabled` | No | `true` | Render the cert-manager integration (ClusterIssuer + Usage). Set `false` when cert-manager is not installed |
| `certManager.name` | No | `cert-manager` | metadata.name of the external cert-manager Helm Release (for the deletion-ordering Usage) |
| `clusterIssuer.enabled` | No | `true` | Create the ClusterIssuer (within the cert-manager integration) |
| `clusterIssuer.email` | No | - | Let's Encrypt registration email |
| `clusterIssuer.staging` | No | `false` | Use staging ACME server |

## Development

```bash
make render          # Render all examples
make validate        # Validate all examples
make test            # Run unit tests
make e2e             # Run E2E tests
```

## License

Apache-2.0
