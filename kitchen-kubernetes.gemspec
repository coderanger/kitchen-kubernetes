#
# Copyright 2017, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen-kubernetes/version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-kubernetes'
  spec.version       = KitchenKubernetes::VERSION
  spec.authors       = ['Noah Kantrowitz']
  spec.email         = ['noah@coderanger.net']
  spec.description   = %q{A Kubernetes Driver for Test Kitchen}
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/coderanger/kitchen-kubernetes'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'test-kitchen', '~> 1.18'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'

  # Unit testing gems.
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'rspec-its', '~> 1.2'
  spec.add_development_dependency 'fuubar', '~> 2.0'
  spec.add_development_dependency 'simplecov', '~> 0.9'
  spec.add_development_dependency 'codecov', '~> 0.0', '>= 0.0.2'
end
