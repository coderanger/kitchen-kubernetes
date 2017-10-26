# Kitchen-Kubernetes

[![Build Status](https://img.shields.io/travis/coderanger/kitchen-kubernetes.svg)](https://travis-ci.org/coderanger/kitchen-kubernetes)
[![Gem Version](https://img.shields.io/gem/v/poise.svg)](https://rubygems.org/gems/poise)
[![Coverage](https://img.shields.io/codecov/c/github/coderanger/kitchen-kubernetes.svg)](https://codecov.io/github/coderanger/kitchen-kubernetes)
[![Gemnasium](https://img.shields.io/gemnasium/coderanger/kitchen-kubernetes.svg)](https://gemnasium.com/coderanger/kitchen-kubernetes)
[![License](https://img.shields.io/badge/license-Apache_2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

A [Test Kitchen](https://kitchen.ci/) driver for testing on top of a Kubernetes
cluster. It is currently aimed at Chef cookbook testing, though see the [FAQ](#FAQ)
for more information on other testing target.

## Quick Start

First install the driver:

```bash
chef gem install kitchen-kubernetes
```

Then configure your `.kitchen.yml` to use the driver:

```yaml
driver:
  name: kubernetes
```

No other options should be required for the default case but [see below](#options)
for more information on available configuration options.

## Options

You can customize things by setting additional options in the `driver` section,
for example:

```yaml
driver:
  name: kubernetes
  kubectl_command: ~/bin/kubectl
  chef_version: 13.5.21
```

* `cache_path` - Host path for the Chef installation cache. See [below](#chef-install). *(default: /data/chef/%{chef_version})*
* `cache_volume` - Kubernetes [volume](https://kubernetes.io/docs/api-reference/v1.8/#volume-v1-core) description for the Chef install volume. *(default: auto-generated)*
* `chef_image` - Docker data image to get the Chef installation from. *(default: chef/chef)*
* `chef_version` - Version of the Chef data image to use. *(default: latest)*
* `image` - Docker image for the main container in the pod, where Chef is run. *(default: based on the platform name and version)*
* `kubectl_command` - Path to the `kubectl` command to use. *(default: kubectl)*
* `pod_name` - Name of the generated pod. *(default: auto-generate)*
* `pod_template` - Path to the Erb template to create the pod. See [below](#pod). *(default: internal)*
* `rsync_command` - Path to the `rsync` command to use. *(default: rsync)*
* `rsync_image` - Docker image to use for the rsync container in the pod. *(default: kitchenkubernetes/rsync)*

## Chef Install

In a similar fashion to [`kitchen-dokken`](https://github.com/someara/kitchen-dokken/),
this driver uses the `chef/chef` Docker Hub images instead of the normal Chef
installers. Unfortunately Kubernetes doesn't support using Docker images as
volumes directly, so there has to be some copying from the data container in to a
volume shared between the data container and main container.

So as to reduce the disk I/O from launching our test pods (a Chef install is
about 50MB so this is ~100MB of file I/O each time) we use a hostPath volume to
give the cache some persistence between test runs. You can control the location
of this hostPath volume using the `cache_path` configuration option:

```yaml
driver:
  name: kubernetes
  cache_path: /home/k8s/chef_cache/%{chef_version}
```

You can also unset `cache_path` to totally disable the cache and use an
`emptyDir` volume instead:

```yaml
driver:
  name: kubernetes
  cache_path: null
```

If you have another shared storage option available, you can also set
`cache_volume` to a Kuberenetes [Volume object]((https://kubernetes.io/docs/api-reference/v1.8/#volume-v1-core))
(minus the `name` field) and that will be used instead:

```yaml
driver:
  name: kubernetes
  cache_volume:
    persistentVolumeClaim:
      claimName: myclaim
```

## Pod

The default pod created for testing involves three containers and two volumes.

The `chef` volume is [discussed above](#chef-install) and contains the `/opt/chef`
folder of the Chef installation. The `kitchen` volume is an `emptyDir` used for
sending files in to the test container.

The `chef` container is an initContainer (meaning it runs before the other two)
which handles copying the Chef install from the data container to the `chef`
volume (with some caching by default so most of the time it does nothing, as mentioned
above). The `rsync` container runs a small image containing nothing but Rsync,
used [as part of the file upload system](#transport). The `default` container is
where Chef is run, as well as the eventual tests.

If overriding the `pod_template` configuration option, make sure your pod template
also includes containers named `default` and `rsync`.

## Transport

Careful observers will note that their `kitchen list` output shows that not just
the driver is set to `Kubernetes`, but the transport is too:

```bash
$ kitchen list
Instance                    Driver      Provisioner  Verifier  Transport   Last Action    Last Error
default-centos-7            Kubernetes  ChefSolo     Busser    Kubernetes  <Not Created>  <None>
```

This transport plugin is configured automatically by the driver for your convenience
and uses `kubectl exec` for running commands on the test container. For sending
files, rsync is used. The rsync data is also sent over `kubectl exec` to avoid
needing to configure any additional network login services. This uses the `rsync`
container in the pod and the `kitchen` volume.

## FAQ

### Can I use this for testing things other than Chef?

Not currently, but it could definitely be added. If you're interested in a
particular provisioner, open an issue so I know there is user demand.

### Can I test Kubernetes objects like deployments and services?

Not yet, though it is planned. If you have a specific use case in mind, please
open an issue and let me know.

### Will this work with GKE/AKE/etc?

I think so but haven't tested it myself.

### Will this work with minkube?

Yes, just make sure you have the minikube config context activated.

## Sponsors

Development sponsored by [SAP](https://www.sap.com/).

The Poise test server infrastructure is generously sponsored by [Rackspace](https://rackspace.com/). Thanks Rackspace!

## License

Copyright 2013-2016, Noah Kantrowitz

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
