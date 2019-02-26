require 'tomlrb'
require 'mixlib/cli'
require 'net/http'
require 'json'
require 'tempfile'

STDOUT.sync = true

module Hab
  module Depot
    class Sync
      include Mixlib::CLI

      banner "#{File.basename($PROGRAM_NAME)} (options)"

      option :source_depot,
        long: '--source-depot URL',
        default: 'https://bldr.habitat.sh',
        description: "Source depot to sync artifacts from. Default: https://bldr.habitat.sh"

      option :source_auth_token,
        long: '--source-auth-token TOKEN',
        description: 'Source auth token to use.'

      option :origin,
        long: '--origin ORIGIN',
        default: 'core',
        description: 'Origin to mirror. Default: core'

      option :channel,
        long: '--channel CHANNEL',
        default: 'stable',
        description: 'Channel to mirror. Default: stable'

      option :dest_depot,
        long: '--dest-depot URL',
        default: 'http://localhost',
        description: "Destination depot to sync artifacts from. Default: https://bldr.habitat.sh"

      option :dest_auth_token,
        long: '--dest-auth-token TOKEN',
        description: 'Destination auth token to use.'

      option :latest_version,
        long: '--latest-version',
        default: false,
        description: 'If true - copy only latest version for each package.'

      option :latest_release,
        long: '--latest-release',
        default: false,
        description: 'If true - copy only latest release for each version.'

      option :read_timeout,
        long: '--read-timeout TIMEOUT',
        default: 240,
        proc: ->(x) { Integer(x) },
        description: 'Timeout for Net::HTTP operations. Default: 120.'

      option :cache,
        long: '--cache FILE',
        default: '/tmp/hab-depot-sync.json',
        description: 'Sync cache for resume to work'

      def run
        parse_options

        dest_keys = list_origin_keys(config[:dest_depot], config[:dest_auth_token], config[:origin])
        source_keys = list_origin_keys(config[:source_depot], config[:source_auth_token], config[:origin])

        sync_keys = source_keys - dest_keys

        len = sync_keys.length
        rj = len.to_s.length

        puts "Keys already synced!" if len.zero?
        sync_keys.each_with_index do |sk, idx|
          puts "[#{(idx + 1).to_s.rjust(rj)}/#{len}] Syncing #{sk['location']}"
          content = download_origin_key(config[:source_depot], config[:source_auth_token], config[:origin], sk['revision'])

          upload_origin_key(config[:dest_depot], config[:dest_auth_token], config[:origin], sk['revision'], content)
        end


        # PACKAGES

        if File.exist?(config[:cache])
          puts "  Resuming job from #{config[:cache]}"

          diff_packages = JSON.parse(IO.read(config[:cache])) rescue []

          if diff_packages.empty?
            puts "   Cache file invalid or empty. Delete it."
            exit 1
          end
        else
          puts "Using only latest release for each package version" if config[:latest_release]

          if config[:latest_version]
            puts "Using only latest version for each package"
            config[:latest_release] = true
          end

          dest_packages = list_origin_packages(config[:dest_depot], config[:dest_auth_token], config[:origin], config[:channel])
          dest_packages.map! { |x| x.delete('release'); x }.uniq! if config[:latest_release]
          dest_packages.map! { |x| x.delete('version'); x }.uniq! if config[:latest_version]

          source_packages = list_origin_packages(config[:source_depot], config[:source_auth_token], config[:origin], config[:channel])
          source_packages.map! { |x| x.delete('release'); x }.uniq! if config[:latest_release]
          source_packages.map! { |x| x.delete('version'); x }.uniq! if config[:latest_version]

          diff_packages = source_packages - dest_packages
          File.write(config[:cache], diff_packages.to_json)
        end


        len = diff_packages.length
        rj = len.to_s.length

        diff_packages.each_with_index do |dp, idx|
          puts "[#{(idx + 1).to_s.rjust(rj)}/#{len}] Syncing #{dp['name']}/#{dp['version'] || 'latest'}/#{dp['release'] || 'latest'}"

          puts "   Get source meta"
          source_meta = get_package_metadata(config[:source_depot], config[:source_auth_token], config[:origin], config[:channel], dp['name'], dp['version'], dp['release'])

          next unless source_meta

          id = source_meta['ident']
          puts "   Get destination meta"
          dest_meta = get_package_metadata(config[:dest_depot], config[:dest_auth_token], config[:origin], 'unstable', id['name'], id['version'], id['release'])

          unless dest_meta
            puts "   No destination package, no metadata"
            puts "     Download source"
            file = download_origin_package(config[:source_depot], config[:source_auth_token], config[:origin], id['name'], id['version'], id['release'])

            puts "     Upload file with checksum: #{source_meta['checksum']}"
            upload_origin_package(config[:dest_depot], config[:dest_auth_token], config[:origin], id['name'], id['version'], id['release'], file, source_meta['checksum'])

            # Give builder some time
            sleep 0.1

            puts "   Refresh destination meta"
            dest_meta = get_package_metadata(config[:dest_depot], config[:dest_auth_token], config[:origin], 'unstable', id['name'], id['version'], id['release'])
          end

          next unless dest_meta

          if source_meta['checksum'] != dest_meta['checksum']
            puts "-> * FAILED CHECKSUM #{dest_meta['ident']}! * <-"
            next
          end

          if dest_meta['channels'].include? config[:channel]
            puts "   Already promoted"
          else
            puts "   Promote"
            promote_origin_package(config[:dest_depot], config[:dest_auth_token], config[:origin], config[:channel], id['name'], id['version'], id['release'])
          end
        end

        File.delete(config[:cache])
      end

      def list_origin_keys(bldr, token, origin)
        JSON.parse(get(bldr, token, "/v1/depot/origins/#{origin}/keys"))
      end

      def download_origin_key(bldr, token, origin, revision)
        get(bldr, token, "/v1/depot/origins/#{origin}/keys/#{revision}")
      end

      def upload_origin_key(bldr, token, origin, revision, content)
        post(bldr, token, "/v1/depot/origins/#{origin}/keys/#{revision}", content)
      end

      def list_origin_packages(bldr, token, origin, channel, max = 100_000_000)
        pkg_list = []
        range = 0

        while true
          resp = JSON.parse(get(bldr, token, "/v1/depot/channels/#{origin}/#{channel}/pkgs?range=#{range}"))
          pkg_list += resp['data']
          range = resp['range_end'] + 1

          break if range > resp['total_count'] || range > max
        end

        pkg_list
      end

      def get_package_metadata(bldr, token, origin, channel, package, version, release)
        version ||= 'latest'
        release ||= 'latest'

        ident = [package, version]
        ident << release unless version == 'latest'
        ident = ident.join('/')

        JSON.parse(get(bldr, token, "/v1/depot/channels/#{origin}/#{channel}/pkgs/#{ident}")) rescue nil
      end

      def download_origin_package(bldr, token, origin, package, version, release)
        get(bldr, token, "/v1/depot/pkgs/#{origin}/#{package}/#{version}/#{release}/download")
      end

      def upload_origin_package(bldr, token, origin, package, version, release, hart, checksum)
        post(bldr, token, "/v1/depot/pkgs/#{origin}/#{package}/#{version}/#{release}?checksum=#{checksum}", hart)
      end

      def promote_origin_package(bldr, token, origin, channel, package, version, release)
        put(bldr, token, "/v1/depot/channels/#{origin}/#{channel}/pkgs/#{package}/#{version}/#{release}/promote", nil)
      end

      def get(bldr, token, path)
        uri = URI.parse("#{bldr}#{path}")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = config[:read_timeout]

        request = Net::HTTP::Get.new(uri.request_uri)

        request['Authorization'] = "Bearer #{token}" if token
        request['Accept'] = 'application/json'

        # require 'pry';binding.pry

        response = http.request(request)

        case response
        when Net::HTTPOK
          puts "   200 #{uri}."
          return response.body

        when Net::HTTPPartialContent
          puts "   206 #{uri}. Pagination required!"
          return response.body

        else

          puts "   Warn: unexpected response for #{uri}. #{response.class} - #{response.body}"
        end
      end

      def post(bldr, token, path, content)
        uri = URI.parse("#{bldr}#{path}")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = config[:read_timeout]

        request = Net::HTTP::Post.new(path)
        request['Authorization'] = "Bearer #{token}" if token
        request['Content-Type'] = 'text/plain'
        request.body = content

        # require 'pry';binding.pry

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          puts "   Post OK #{uri}"
        else
          puts "   Warn: unexpected response for #{uri}. #{response.class} - #{response.body}"
        end
      end

      def put(bldr, token, path, content)
        uri = URI.parse("#{bldr}#{path}")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = config[:read_timeout]

        request = Net::HTTP::Put.new(path)
        request['Authorization'] = "Bearer #{token}" if token
        request['Content-Type'] = 'text/plain'
        request.body = content

        # require 'pry';binding.pry

        response = http.request(request)

        case response
        when Net::HTTPSuccess
          puts "   Post OK #{uri}"
        else
          puts "   Warn: unexpected response for #{uri}. #{response.class} - #{response.body}"
        end
      end
    end
  end
end
