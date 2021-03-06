require 'chef_fs/knife'
require 'chef_fs/file_system'

class Chef
  class Knife
    class Delete < ChefFS::Knife
      banner "knife delete [PATTERN1 ... PATTERNn]"

      common_options

      option :recurse,
        :long => '--[no-]recurse',
        :boolean => true,
        :default => false,
        :description => "Delete directories recursively."

      def run
        # Get the matches (recursively)
        pattern_args.each do |pattern|
          ChefFS::FileSystem.list(chef_fs, pattern) do |result|
            begin
              result.delete(config[:recurse])
              puts "Deleted #{result.path_for_printing}"
            rescue ChefFS::FileSystem::NotFoundError
              STDERR.puts "result.path_for_printing}: No such file or directory"
            end
          end
        end
      end
    end
  end
end

