actions :install, :test, :reload_cpan_index
attribute :install_base, :kind_of => String
attribute :inc, :default => [], :kind_of => Array
attribute :install_path, :default => [], :kind_of => Array
attribute :dry_run, :kind_of => [TrueClass, FalseClass], :default => false
attribute :force, :kind_of => [TrueClass, FalseClass], :default => false
attribute :from_cookbook, :kind_of => String
attribute :reload_cpan_index, :kind_of => [TrueClass, FalseClass], :default => false
attribute :name , :kind_of => String
attribute :environment , :kind_of => Hash, :default => Hash.new
attribute :cwd , :kind_of => String, :default => ENV['PWD']
attribute :install_type, :kind_of => String, :default => 'application'
attribute :user , :kind_of => String
attribute :group , :kind_of => String
attribute :version , :kind_of => String

