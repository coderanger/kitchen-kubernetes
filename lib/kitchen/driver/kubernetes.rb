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

require 'erb'
require 'json'

require 'kitchen/driver/base'
require 'kitchen/provisioner/chef_base'
require 'kitchen/shell_out'
require 'kitchen/verifier/busser'

require 'kitchen/transport/kubernetes'

module Kitchen
  module Driver

    # Kubernetes driver for Kitchen.
    #
    # @author Noah Kantrowitz <noah@coderanger>
    # @since 1.0.0
    # @see Kitchen::Transport::Kubernetes
    class Kubernetes < Kitchen::Driver::Base
      include ShellOut

      default_config :cache_path, '/data/chef/%{chef_version}'
      default_config :chef_image, 'chef/chef'
      default_config :chef_version, 'latest'
      default_config :kubectl_command, 'kubectl'
      default_config :pod_template, File.expand_path('../pod.yaml.erb', __FILE__)
      default_config :rsync_command, 'rsync'
      default_config :rsync_image, 'kitchenkubernetes/rsync:3.1.2-r5'
      default_config :rsync_rsh, "#{RbConfig.ruby} -e \"exec('kubectl', 'exec', '--stdin', '--container=rsync', ARGV[0], '--', *ARGV[1..-1])\""

      default_config :cache_volume do |driver|
        if driver[:cache_path]
          path = driver[:cache_path] % {chef_version: driver[:chef_version]}
          {hostPath: {path: path, type: 'DirectoryOrCreate'}}
        else
          {emptyDir: {}}
        end
      end

      default_config :image do |driver|
        if driver.instance.platform.name =~ /^(.*)-([^-]*)$/
          "#{$1}:#{$2}"
        else
          driver.instance.platform.name
        end
      end

      default_config :pod_name do |driver|
        # Borrowed from kitchen-rackspace
        [
          driver.instance.name.gsub(/\W/, ''),
          (Etc.getlogin || 'nologin').gsub(/\W/, ''),
          Socket.gethostname.gsub(/\W/, '')[0..20],
          Array.new(8) { rand(36).to_s(36) }.join
        ].join('-')
      end

      expand_path_for :kubectl_command
      expand_path_for :pod_template
      expand_path_for :rsync_command

      # Muck with some other plugins to make the UX easier. Haxxxx.
      #
      # @api private
      def finalize_config!(instance)
        super.tap do
          # Force the use of the Kubernetes transport since it isn't much use
          # without that.
          instance.transport = Kitchen::Transport::Kubernetes.new(config)
          # Leave room for the possibility of other provisioners in the future,
          # but force some options we need.
          if instance.provisioner.is_a?(Kitchen::Provisioner::ChefBase)
            instance.provisioner.send(:config).update(
              require_chef_omnibus: false,
              product_name: nil,
              chef_omnibus_root: '/opt/chef',
              sudo: false,
            )
          end
          # Ditto to the above, other verifiers will need their own hacks, but
          # this is a start at least.
          if instance.verifier.is_a?(Kitchen::Verifier::Busser)
            instance.verifier.send(:config).update(
              root_path: '/tmp/kitchen/verifier',
              sudo: false,
            )
          end
        end
      end

      # (see Base#create)
      def create(state)
        # Already created, we're good.
        return if state[:pod_id]
        # Lock in our name with randomness and whatever.
        state[:pod_id] = config[:pod_name]
        # Render the pod YAML and feed it to kubectl.
        tpl = ERB.new(IO.read(config[:pod_template]))
        tpl.filename = config[:pod_template]
        pod_yaml = tpl.result(binding)
        debug("Creating pod with YAML:\n#{pod_yaml}\n")
        run_command([config[:kubectl_command], 'create', '--filename', '-'], input: pod_yaml)
        # Wait until the pod reaches Running status.
        status = nil
        start_time = Time.now
        while status != 'Running'
          if Time.now - start_time > 20
            # More than 20 seconds, start giving user feedback. 20 second threshold
            # was 100% pulled from my ass based on how long it takes to launch
            # on my local minikube, may need changing for reality.
            info("Waiting for pod #{state[:pod_id]} to be running, currently #{status}")
          end
          sleep(1)
          # Can't use run_command here because error! is unwanted and logging is a bit much.
          status_cmd = Mixlib::ShellOut.new(config[:kubectl_command], 'get', 'pod', state[:pod_id], '--output=json')
          status_cmd.run_command
          unless status_cmd.error? || status_cmd.stdout.empty?
            status = JSON.parse(status_cmd.stdout)['status']['phase']
          end
        end
      end

      # (see Base#destroy)
      def destroy(state)
        return unless state[:pod_id]
        run_command([config[:kubectl_command], 'delete', 'pod', state[:pod_id], '--now'])
        # Explicitly not waiting for the delete to finish, if k8s has problems
        # with deletes in the future, I can add a wait here.
      rescue ShellCommandFailed => ex
        raise unless ex.to_s.include?('(NotFound)')
      end

    end
  end
end
