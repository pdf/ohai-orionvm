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

require 'ipaddr'

Ohai.plugin(:Orionvm) do
  provides 'orionvm', 'cloud'
  depends 'network/interfaces', 'fqdn'

  # Identifies the orionvm cloud
  #
  # === Return
  # true:: If the orionvm cloud can be identified
  # false:: Otherwise
  def looks_like_orionvm?
    hint?('orionvm') || looks_like_orionvm_v2? || looks_like_orionvm_v3?
  end

  # Identifies the orionvm v2 cloud
  #
  # === Return
  # true:: If the orionvm v2 cloud can be identified
  # false:: Otherwise
  def looks_like_orionvm_v2?
    File.exists?('/etc/orion_base')
  end

  # Identifies the orionvm v3 cloud
  #
  # === Return
  # true:: If the orionvm v3 cloud can be identified
  # false:: Otherwise
  def looks_like_orionvm_v3?
    File.exists?('/etc/udev/rules.d/70-contextdrive.rules')
  end

  # Determines whether IP address is private (reserved)
  #
  # === Parameters
  # address<String>:: IP address to test (ie - '192.168.0.1')
  def is_private?(address)
    [
      IPAddr.new('10.0.0.0/8'),
      IPAddr.new('172.16.0.0/12'),
      IPAddr.new('192.168.0.0/16'),
    ].any? do |i|
      i.include? address
    end
  end

  # Names orionvm ip address
  #
  # === Parameters
  # type<Symbol>:: Use :public_ip or :private_ip
  def get_ip_address(type)
    network[:interfaces].each do |iface, info|
      next unless info['type'] == 'eth'
      info[:addresses].each do |addr, detail|
        next unless detail['family'] == 'inet'
        case type
        when :public_ip
          return addr if !is_private?(addr)
        when :private_ip
          return addr if is_private?(addr)
        end
      end
    end
    return nil
  end

  collect_data(:linux) do
    # Adds orionvm Mash and populates cloud values if missing
    if looks_like_orionvm?
      orionvm Mash.new
      cloud Mash.new
      cloud[:public_ips] ||= Array.new
      cloud[:private_ips] ||= Array.new

      public_ip = get_ip_address(:public_ip)
      if public_ip
        orionvm[:public_ipv] = public_ip
        orionvm[:public_ipv4] = public_ip
        cloud[:public_ipv4] = public_ip
        cloud[:public_ips] << public_ip
      end
      private_ip = get_ip_address(:private_ip)
      if private_ip
        orionvm[:private_ip] = private_ip
        orionvm[:local_ipv4] = private_ip
        cloud[:local_ipv4] = private_ip
        cloud[:private_ips] << private_ip
      end
      orionvm[:public_hostname] = fqdn
      orionvm[:local_hostname] = fqdn

      # Fill cloud hash with OrionVM values
      cloud[:public_hostname] = orionvm[:public_hostname]
      cloud[:local_hostname] = orionvm[:local_hostname]
      cloud[:provider] = 'orionvm'

      if looks_like_orionvm_v2?
        orionvm[:version] = 2
      end
      if looks_like_orionvm_v3?
        orionvm[:version] = 3
      end
    end
  end
end
