#
# Author:: Peter Fern (<ruby@0xc0dedbad.com>)
# License:: MIT License
#
# Licensed under the MIT License, Copyright (c) 2013 Peter Fern,
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://opensource.org/licenses/MIT
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

Ohai.plugin(:Orionvm) do
  provides 'orionvm', 'cloud'
  depends 'network/interfaces', 'fqdn'

  # Identifies the orionvm cloud
  #
  # === Return
  # true:: If the orionvm cloud can be identified
  # false:: Otherwise
  def looks_like_orionvm?
    hint?('orionvm') || File.exists?('/etc/orion_base')
  end

  # Names orionvm ip address
  #
  # === Parameters
  # name<Symbol>:: Use :public_ip or :private_ip
  # eth<Symbol>:: Interface name of public or private ip
  def get_ip_address(name, eth)
    network[:interfaces][eth][:addresses].each do |key, info|
      if info['family'] == 'inet'
        orionvm[name] = key
        break # break when we found an address
      end
    end
  end

  collect_data(:linux) do
    # Adds orionvm Mash and populates cloud values if missing
    if looks_like_orionvm?
      orionvm Mash.new
      cloud Mash.new
      get_ip_address(:public_ip, :eth0)
      get_ip_address(:private_ip, :eth1)
      orionvm[:public_ipv4] = orionvm[:public_ip]
      orionvm[:local_ipv4] = orionvm[:private_ip]
      orionvm[:public_hostname] = fqdn
      orionvm[:local_hostname] = fqdn

      # Fill cloud hash with OrionVM values
      cloud[:public_ips] ||= Array.new
      cloud[:private_ips] ||= Array.new
      cloud[:public_ips] << orionvm[:public_ipv4] if orionvm[:public_ipv4]
      cloud[:private_ips] << orionvm[:local_ipv4] if orionvm[:local_ipv4]
      cloud[:public_ipv4] = orionvm[:public_ipv4]
      cloud[:public_hostname] = orionvm[:public_hostname]
      cloud[:local_ipv4] = orionvm[:local_ipv4]
      cloud[:local_hostname] = orionvm[:local_hostname]
      cloud[:provider] = 'orionvm'
    end
  end
end
