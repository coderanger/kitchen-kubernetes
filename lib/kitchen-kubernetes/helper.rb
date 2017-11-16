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


module KitchenKubernetes
  # Utility mixin for other classes in this plugin.
  #
  # @since 1.0
  # @api private
  module Helper
    # Because plugins and connections have different APIs.
    def kube_options
      if defined?(config)
        config
      elsif defined?(options)
        options
      else
        raise "Something went wrong, please file a bug"
      end
    end

    def kubectl_command(*cmd)
      out = [kube_options[:kubectl_command]]
      if kube_options[:context]
        out << '--context'
        out << kube_options[:context]
      end
      out.concat(cmd)
      out
    end
  end
end
