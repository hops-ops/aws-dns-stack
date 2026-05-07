### What's changed in v1.0.0

* feat: drop cert-manager Helm install; compose Route53 PodIdentity for external cert-manager (by @patrickleet)

  BREAKING CHANGE: cert-manager is now expected to be installed separately (e.g. by cert-stack
  at xrs/stacks/k8s/cert). This stack stops composing the cert-manager Helm
  Release and instead owns the AWS-side DNS-01 plumbing: a Route53 PodIdentity
  bound to the external cert-manager ServiceAccount, plus a deletion-ordering
  Usage that protects the ClusterIssuer from being torn down before the
  external Helm Release.

  XRD: spec.certManager exposes enabled + name + namespace only (drops values,
  overrideAllValues). Default labels switch to hops.ops.com.ai/<kind>.

  Implements [[tasks/cert-manager-stack]]

  BREAKING CHANGE: spec.certManager.values and spec.certManager.overrideAllValues
  removed. Consumers needing to configure the cert-manager Helm release should
  do so on aws-cert-stack / cert-stack instead.


See full diff: [v0.6.0...v1.0.0](https://github.com/hops-ops/aws-dns-stack/compare/v0.6.0...v1.0.0)
