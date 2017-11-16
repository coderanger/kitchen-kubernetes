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

require 'shellwords'

require 'kitchen/login_command'
require 'kitchen/shell_out'
require 'kitchen/transport/base'

require 'kitchen-kubernetes/helper'


module Kitchen
  module Transport

    # Kubernetes transport for Kitchen. Uses kubectl exec.
    #
    # @author Noah Kantrowitz <noah@coderanger>
    # @since 1.0.0
    # @see Kitchen::Driver::Kubernetes
    class Kubernetes < Kitchen::Transport::Base
      # All configuration options can be found in the Driver class.

      # (see Base#connection)
      def connection(state, &block)
        # No persistent anything so no need to reuse connections.
        Connection.new(
          pod_id: state[:pod_id],
          kubectl_command: config[:kubectl_command],
          rsync_command: config[:rsync_command],
          rsync_rsh: config[:rsync_rsh],
          logger: logger
        ).tap do |conn|
          block.call(conn) if block
        end
      end

      class Connection < Kitchen::Transport::Base::Connection
        include ShellOut
        include KitchenKubernetes::Helper

        # (see Base::Connection#execute)
        def execute(command)
          return if command.nil?
          # Run via kubectl exec.
          run_command(kubectl_command('exec', '--tty', '--container=default', options[:pod_id], '--', *Shellwords.split(command)))
        end

        # (see Base::Connection#upload)
        def upload(locals, remote)
          return if locals.empty?
          # Use rsync over kubectl exec to send files.
          run_command([options[:rsync_command], '--archive', '--progress', '--rsh', options[:rsync_rsh]] + locals + ["#{options[:pod_id]}:#{remote}"])
        end

        # (see Base::Connection#login_command)
        def login_command
          # Find a valid login shell and exec it. This is so weridly complex
          # because it has to work with a /bin/sh that might be bash, dash, or
          # busybox. Also CentOS images doesn't have `which` for some reason.
          # Dash's `type` is super weird so use `which` first in case of dash but
          # fall back to `type` for basically just CentOS.
          login_cmd = "IFS=$'\n'; for f in `which bash zsh sh 2>/dev/null || type -P bash zsh sh`; do exec \"$f\" -l; done"
          cmd = kubectl_command('exec', '--stdin', '--tty', '--container=default', options[:pod_id], '--', '/bin/sh', '-c', login_cmd)
          LoginCommand.new(cmd[0], cmd.drop(1))
        end
      end
    end
  end
end
