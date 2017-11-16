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
# This is copied from https://github.com/chef/train/pull/205 until InSpec can
# support it internally. The only changes are to rename with _hack and
# back-compat support for the changes in the files API (LinuxFile vs File::Remote::Linux).

require 'mixlib/shellout'

require 'train'

module Train::Transports
  class KubernetesHack < Train.plugin(1)
    name 'kubernetes_hack'

    include_options Train::Extras::CommandWrapper
    option :pod, required: true
    option :container, default: nil
    option :kubectl_path, default: 'kubectl'
    option :context, default: nil

    def connection(state = {})
      opts = merge_options(options, state || {})
      validate_options(opts)
      opts[:logger] ||= logger
      unless @connection && @connection_opts == opts
        @connection ||= Connection.new(opts)
        @connection_opts = opts.dup
      end
      @connection
    end

    class Connection < BaseConnection
      def os
        @os ||= OS.new(self)
      end

      def file(path)
        @files[path] ||= defined?(Train::File::Remote::Linux) ? Train::File::Remote::Linux.new(self, path) : LinuxFile.new(self, path)
      end

      def run_command(cmd)
        kubectl_cmd = [options[:kubectl_path], 'exec']
        kubectl_cmd.concat(['--context', options[:context]]) if options[:context]
        kubectl_cmd.concat(['--container', options[:container]]) if options[:container]
        kubectl_cmd.concat([options[:pod], '--', '/bin/sh', '-c', cmd])

        so = Mixlib::ShellOut.new(kubectl_cmd, logger: logger)
        so.run_command
        if so.error?
          # Trim the "command terminated with exit code N" line from the end
          # of the stderr content.
          so.stderr.gsub!(/command terminated with exit code #{so.exitstatus}\n\Z/, '')
        end
        CommandResult.new(so.stdout, so.stderr, so.exitstatus)
      end

      def uri
        if options[:container]
          "kubernetes://#{options[:pod]}/#{options[:container]}"
        else
          "kubernetes://#{options[:pod]}"
        end
      end

      class OS < OSCommon
        def initialize(backend)
          # hardcoded to unix/linux for now, until other operating systems
          # are supported
          super(backend, { family: 'unix' })
        end
      end
    end
  end
end
