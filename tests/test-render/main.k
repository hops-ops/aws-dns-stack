import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

# ==============================================================================
# Unit tests for aws DNSStack XRD
#
# Note: this stack does NOT install cert-manager. It composes ExternalDNS +
# Route53 hosted zones, plus an optional cert-manager *integration* (a Route53
# IAM PodIdentity bound to the cert-manager ServiceAccount + a Let's Encrypt
# ClusterIssuer + deletion-ordering Usages). The cert-manager Helm Release
# itself is composed by cert-stack (xrs/stacks/k8s/cert/).
# ==============================================================================

_items = [
    # ==========================================================================
    # Test 1: Minimal input renders ExternalDNS + ClusterIssuer integration.
    # No cert-manager Helm Release is composed by this stack — it's expected
    # to come from aws-cert-stack.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-renders-edns-and-cluster-issuer"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "dns-edns"
                    spec = {
                        forProvider.namespace = "external-dns"
                        providerConfigRef.name = "my-cluster"
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "dns-cluster-issuer"
                    spec = {
                        forProvider = {
                            manifest = {
                                apiVersion = "cert-manager.io/v1"
                                kind = "ClusterIssuer"
                                metadata.name = "letsencrypt-prod"
                                spec.acme = {
                                    email = "admin@example.com"
                                    server = "https://acme-v02.api.letsencrypt.org/directory"
                                    privateKeySecretRef.name = "letsencrypt-prod-account-key"
                                    solvers = [{
                                        dns01.route53.region = "us-east-1"
                                    }]
                                }
                            }
                        }
                        providerConfigRef = {
                            name = "my-cluster"
                            kind = "ProviderConfig"
                        }
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 2: Staging flag switches to LE staging server and name
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "staging-flag-switches-server"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                        staging = True
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "dns-cluster-issuer"
                    spec.forProvider.manifest = {
                        apiVersion = "cert-manager.io/v1"
                        kind = "ClusterIssuer"
                        metadata.name = "letsencrypt-staging"
                        spec.acme = {
                            server = "https://acme-staging-v02.api.letsencrypt.org/directory"
                            email = "admin@example.com"
                            privateKeySecretRef.name = "letsencrypt-staging-account-key"
                        }
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 3: Provider config refs propagate correctly
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "provider-config-refs-propagate"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    helmProviderConfigRef = {
                        name = "custom-helm"
                        kind = "ClusterProviderConfig"
                    }
                    kubernetesProviderConfigRef = {
                        name = "custom-k8s"
                    }
                    awsProviderConfigRef = {
                        name = "custom-aws"
                    }
                    aws = {
                        region = "eu-west-1"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "dns-edns"
                    spec.providerConfigRef = {
                        name = "custom-helm"
                        kind = "ClusterProviderConfig"
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "dns-cluster-issuer"
                    spec.providerConfigRef = {
                        name = "custom-k8s"
                        kind = "ProviderConfig"
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 4: certManager.enabled=false skips the entire integration —
    # no ClusterIssuer, no cert-manager PodIdentity, no Usages. ExternalDNS
    # still renders.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "cert-manager-disabled-skips-integration"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    certManager = {
                        enabled = False
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "dns-edns"
                }
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "DNSStack"
                    metadata.name = "dns"
                    status.ready = False
                }
            ]
        }
    }

    # ==========================================================================
    # Test 5: cert-manager integration composes a Usage referencing the
    # external Release (default name "cert-manager", matching aws-cert-stack's
    # spec.releaseName default).
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "integration-usage-references-external-release-by-default"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "dns-delete-cluster-issuer-before-cert-manager"
                    spec = {
                        of = {
                            apiVersion = "helm.m.crossplane.io/v1beta1"
                            kind = "Release"
                            resourceRef.name = "cert-manager"
                        }
                        by = {
                            apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                            kind = "Object"
                            resourceRef.name = "dns-cluster-issuer"
                        }
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 5b: Override the external Release name via spec.certManager.name.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "integration-usage-honors-cert-manager-name-override"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    certManager = {
                        name = "my-custom-cm-release"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "dns-delete-cluster-issuer-before-cert-manager"
                    spec.of.resourceRef.name = "my-custom-cm-release"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 6: AWS config passes through to both PodIdentities (ExternalDNS
    # and cert-manager) — they share the same aws.* settings.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "aws-config-passthrough"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "prod-cluster"
                    aws = {
                        region = "us-west-2"
                        permissionsBoundaryArn = "arn:aws:iam::123456789012:policy/boundary"
                        rolePrefix = "prod-"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "PodIdentity"
                    metadata.name = "dns-edns"
                    spec = {
                        region = "us-west-2"
                        permissionsBoundaryArn = "arn:aws:iam::123456789012:policy/boundary"
                        rolePrefix = "prod-"
                    }
                }
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "PodIdentity"
                    metadata.name = "dns-cm"
                    spec = {
                        region = "us-west-2"
                        permissionsBoundaryArn = "arn:aws:iam::123456789012:policy/boundary"
                        rolePrefix = "prod-"
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 6b: cert-manager PodIdentity binds to the cert-manager SA in the
    # configured namespace (defaults to "cert-manager").
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "cert-manager-pod-identity-binds-to-cert-manager-sa"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "PodIdentity"
                    metadata.name = "dns-cm"
                    spec.serviceAccount = {
                        name = "cert-manager"
                        namespace = "cert-manager"
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 6c: certManager.namespace override flows to the PodIdentity SA
    # binding (matches a non-default cert-stack namespace).
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "cert-manager-namespace-override-flows-to-pod-identity"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    certManager = {
                        namespace = "tls-system"
                    }
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "PodIdentity"
                    metadata.name = "dns-cm"
                    spec.serviceAccount.namespace = "tls-system"
                }
            ]
        }
    }

    # ==========================================================================
    # Test 7: Domains create Route53 Zone resources
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "domains-create-hosted-zones"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    domains = [
                        {name = "example.com"}
                        {name = "internal.example.com"}
                    ]
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "route53.aws.m.upbound.io/v1beta1"
                    kind = "Zone"
                    metadata.name = "dns-hz-example-com"
                    spec = {
                        forProvider.name = "example.com"
                        providerConfigRef.name = "default"
                    }
                }
                {
                    apiVersion = "route53.aws.m.upbound.io/v1beta1"
                    kind = "Zone"
                    metadata.name = "dns-hz-internal-example-com"
                    spec = {
                        forProvider.name = "internal.example.com"
                        providerConfigRef.name = "default"
                    }
                }
            ]
        }
    }

    # ==========================================================================
    # Test 8: domainFilters auto-wired into ExternalDNS values
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "domain-filters-auto-wired"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    domains = [
                        {name = "example.com"}
                    ]
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "dns-edns"
                    spec.forProvider.values.domainFilters = ["example.com"]
                }
            ]
        }
    }

    # ==========================================================================
    # Test 9: externalName annotation set when provided
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "external-name-annotation-set"
        spec = {
            compositionPath = "apis/dnsstacks/composition.yaml"
            xrdPath = "apis/dnsstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "DNSStack"
                metadata.name = "dns"
                spec = {
                    clusterName = "my-cluster"
                    aws = {
                        region = "us-east-1"
                    }
                    domains = [
                        {name = "example.com", externalName = "Z1234567890ABC"}
                    ]
                    clusterIssuer = {
                        email = "admin@example.com"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "route53.aws.m.upbound.io/v1beta1"
                    kind = "Zone"
                    metadata = {
                        name = "dns-hz-example-com"
                        annotations = {
                            "crossplane.io/external-name" = "Z1234567890ABC"
                        }
                    }
                }
            ]
        }
    }
]

items = _items
