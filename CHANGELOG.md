### What's changed in v1.5.1

* chore(deps): migrate workflows-crossplane to hops-ops@v3.2.0 (by @renovate[bot])

  * chore(deps): update unbounded-tech/workflows-crossplane action to v3

  * chore(deps): migrate workflows-crossplane to hops-ops@v3.2.0

  ---------

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>
  Co-authored-by: Patrick Lee Scott <pat@patscott.io>

* chore(deps): update helm release external-dns to v1.22.0 (#22) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

* fix(deps): pin external-dns annotationPrefix to alpha (post-1.22) (by @patrickleet)

  Renovate merged external-dns 1.22.0 without pinning annotationPrefix.
  App 0.22 defaults to GA prefix with no alpha fallback, which can delete
  DNS records that still use external-dns.alpha.kubernetes.io annotations.
  Keep alpha until we deliberately migrate annotations.


See full diff: [v1.5.0...v1.5.1](https://github.com/hops-ops/aws-dns-stack/compare/v1.5.0...v1.5.1)
