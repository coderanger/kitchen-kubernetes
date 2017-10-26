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

require 'serverspec'
set :backend, :exec

describe file('/testfile') do
  it { is_expected.to be_a_file }
  it { is_expected.to be_owned_by 'root' }
  it { is_expected.to be_mode 741 }
  its(:content) { is_expected.to eq "I am a teapot\n" }
end

describe file('/testtemplate') do
  it { is_expected.to be_a_file }
  it { is_expected.to be_owned_by 'root' }
  it { is_expected.to be_mode 444 }
  its(:content) { is_expected.to match /^ver=13/ }
end
