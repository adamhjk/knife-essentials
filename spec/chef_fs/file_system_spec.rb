require 'chef_fs/file_system'
require 'chef_fs/file_system/base_fs_dir'
require 'chef_fs/file_system/base_fs_object'
require 'chef_fs/file_pattern'

module FileSystemRSpecSupport
	class MemoryFile < ChefFS::FileSystem::BaseFSObject
		def initialize(name, parent, value)
			super(name, parent)
			@value = value
		end
		def read
			return @value
		end
	end

	class MemoryDir < ChefFS::FileSystem::BaseFSDir
		def initialize(name, parent)
			super(name, parent)
			@children = []
		end
		attr_reader :children
		def child(name)
			@children.select { |child| child.name == name }.first || ChefFS::FileSystem::NonexistentFSObject.new(name, self)
		end
		def add_child(child)
			@children.push(child)
		end
	end

	class ReturnPaths < RSpec::Matchers::BuiltIn::MatchArray
	  def initialize(expected)
	  	super(expected)
	  end
	  def matches?(results)
	  	super(results.map { |result| result.path })
	  end
	end

	def memory_fs(value, name = '', parent = nil)
		if value.is_a?(Hash)
			dir = MemoryDir.new(name, parent)
			value.each do |key, child|
				dir.add_child(memory_fs(child, key.to_s, dir))
			end
			dir
		else
			MemoryFile.new(name, parent, value)
		end
	end

	def pattern(p)
		ChefFS::FilePattern.new(p)
	end

	def return_paths(*expected)
		ReturnPaths.new(expected)
	end

	def no_blocking_calls_allowed
		[ MemoryFile, MemoryDir ].each do |c|
			[ :children, :exists?, :read ].each do |m|
				c.any_instance.stub(m).and_raise("#{m.to_s} should not be called")
			end
		end
	end

	def list_should_yield_paths(fs, pattern_str, *expected)
		results = []
		ChefFS::FileSystem.list(fs, pattern(pattern_str)) { |result| results << result }
		results.should return_paths(*expected)
	end
end

describe ChefFS::FileSystem do
	include FileSystemRSpecSupport

	context 'with empty filesystem' do
		let(:fs) { memory_fs({}) }

		context 'list' do

		end
	end

	context 'with a normal filesytem' do
		let(:fs) {
			memory_fs({
				:a => {
					:aa => {
						:c => '',
						:zz => ''
					},
					:ab => {
						:c => '',
					}
				},
				:x => ''
			})
		}
		context 'list' do
			it '/**' do
				list_should_yield_paths(fs, '/**', '/', '/a', '/x', '/a/aa', '/a/aa/c', '/a/aa/zz', '/a/ab', '/a/ab/c')
			end
			it '/' do
				list_should_yield_paths(fs, '/', '/')
			end
			it '/*' do
				list_should_yield_paths(fs, '/*', '/', '/a', '/x')
			end
			it '/*/*' do
				list_should_yield_paths(fs, '/*/*', '/a/aa', '/a/ab')
			end
			it '/*/*/*' do
				list_should_yield_paths(fs, '/*/*/*', '/a/aa/c', '/a/aa/zz', '/a/ab/c')
			end
			it '/*/*/?' do
				list_should_yield_paths(fs, '/*/*/?', '/a/aa/c', '/a/ab/c')
			end
			it '/a/*/c' do
				list_should_yield_paths(fs, '/a/*/c', '/a/aa/c', '/a/ab/c')
			end
			it '/**b/c' do
				list_should_yield_paths(fs, '/**b/c', '/a/ab/c')
			end
			it '/a/ab/c' do
				no_blocking_calls_allowed
				list_should_yield_paths(fs, '/a/ab/c', '/a/ab/c')
			end
			it 'nonexistent /a/ab/blah' do
				no_blocking_calls_allowed
				list_should_yield_paths(fs, '/a/ab/blah', '/a/ab/blah')
			end
			it 'nonexistent /a/ab/blah/bjork' do
				no_blocking_calls_allowed
				list_should_yield_paths(fs, '/a/ab/blah/bjork')
			end
		end

		context 'resolve_path' do
			before(:each) do
				no_blocking_calls_allowed
			end
			it 'resolves /' do
				ChefFS::FileSystem.resolve_path(fs, '/').path.should == '/'
			end
			it 'resolves /x' do
				ChefFS::FileSystem.resolve_path(fs, '/x').path.should == '/x'
			end
			it 'resolves /a' do
				ChefFS::FileSystem.resolve_path(fs, '/a').path.should == '/a'
			end
			it 'resolves /a/aa' do
				ChefFS::FileSystem.resolve_path(fs, '/a/aa').path.should == '/a/aa'
			end
			it 'resolves /a/aa/zz' do
				ChefFS::FileSystem.resolve_path(fs, '/a/aa/zz').path.should == '/a/aa/zz'
			end
			it 'resolves nonexistent /y/x/w' do
				ChefFS::FileSystem.resolve_path(fs, '/y/x/w').path.should == '/y/x/w'
			end
		end
	end
end
