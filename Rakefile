# NOTE! When updating this file, also update INSTALL, if necessary.
# NOTE! Please keep your tasks grouped together.

$VERBOSE = true
$verbose = Rake.application.options.trace
$dlext = Config::CONFIG["DLEXT"]
$compiler = nil

RUBINIUS_BASE = File.expand_path(File.dirname(__FILE__))

require 'tsort'
require 'rakelib/rubinius'
require 'rakelib/git'

task :default => :build

# BUILD TASKS

desc "Build everything that needs to be built"
task :build => 'build:all'

task :stable_compiler do
  if ENV['USE_CURRENT']
    puts "Use current versions, not stable."
  else
    ENV['RBX_BOOTSTRAP'] = "runtime/stable/bootstrap.rba"
    ENV['RBX_DELTA'] = "runtime/stable/delta.rba"
    ENV['RBX_COMMON'] = "runtime/stable/common.rba"
    ENV['RBX_LOADER'] = "runtime/stable/loader.rbc"
    ENV['RBX_PLATFORM'] = "runtime/stable/platform.rba"
  end
end

rule ".rbc" => %w[.rb] do |t|
  compile t.source, t.name
end

files = FileList['kernel/delta/*.rb']

unless files.include?("kernel/delta/dir.rb")
  files.add("kernel/delta/dir.rb")
end

Common     = CodeGroup.new('kernel/common/*.rb', 'runtime/common', 'common')
Delta      = CodeGroup.new(files, 'runtime/delta', 'delta')

Bootstrap = CodeGroup.new 'kernel/bootstrap/*.rb', 'runtime/bootstrap',
                          'bootstrap'
PlatformFiles  = CodeGroup.new 'kernel/platform/*.rb', 'runtime/platform', 'platform'

file 'runtime/loader.rbc' => 'kernel/loader.rb' do
  compile 'kernel/loader.rb', 'runtime/loader.rbc'
end

file 'runtime/stable/loader.rbc' => 'runtime/loader.rbc' do
  cp 'runtime/loader.rbc', 'runtime/stable', :verbose => $verbose
end

file 'runtime/stable/compiler.rba' => 'build:compiler' do |t|
  #sh "cd lib; zip -r ../runtime/stable/compiler.rba compiler -x \\*.rb"
  rm_f t.name
  rbc_files = Rake::FileList['compiler/**/*.rbc']

  Dir.chdir 'lib' do
    rbc_files.each do |rbc_file|
      ar_add "../#{t.name}", rbc_file
    end
  end
end

AllPreCompiled = Common.output + Delta.output + Bootstrap.output + PlatformFiles.output
AllPreCompiled << "runtime/loader.rbc"

namespace :build do

  task :all => %w[
    build:system

    compiler

    lib/etc.rb
    lib/rbconfig.rb

    extensions

    gems:install_development
  ]

  desc "Builds the core components for running rbx"
  task :system => %w[
    build:shotgun
    build:platform
    build:rbc
  ]

  # This nobody rule lets use use all the shotgun files as
  # prereqs. This rule is run for all those prereqs and just
  # (obviously) does nothing, but it makes rake happy.
  rule '^shotgun/.+'

  # These files must be excluded from the c_source FileList
  # because they are build products (i.e. there is no rule
  # to build them, they will be built) and the c_source list
  # list gets created before they are deleted by the clean task.
  exclude_source = [
    /auto/,
    /instruction_names/,
    /node_types/,
    /grammar.c/,
    'primitive_indexes.h',
    'primitive_util.h'
  ]

  c_source = FileList[
    "shotgun/config.h",
    "shotgun/lib/*.[chy]",
    "shotgun/lib/*.rb",
    "shotgun/lib/subtend/*.[chS]",
    "shotgun/main.c"
  ].exclude(*exclude_source)

  file "shotgun/rubinius.bin" => c_source do
    sh make('vm')
  end

  file "shotgun/dev-tramp" => "shotgun/dev-tramp.c" do
    sh "cc -DBUILDDIR=\\\"#{Dir.pwd}/shotgun\\\" -o shotgun/dev-tramp shotgun/dev-tramp.c"
  end

  file "shotgun/rubinius.local.bin" => c_source + ["shotgun/dev-tramp"] do
    sh make('vm')
  end

  desc "Compiles shotgun (the C-code VM)"
  task :shotgun => %w[configure shotgun/rubinius.bin shotgun/rubinius.local.bin]

  task :setup_rbc => :stable_compiler

  task :rbc => ([:setup_rbc] + AllPreCompiled)

  task :compiler => :stable_compiler do
    compile_dir "lib/compiler"
  end

  desc "Rebuild runtime/stable/*.  If you don't know why you're running this, don't."
  task :stable => %w[
    build:all
    runtime/stable/bootstrap.rba
    runtime/stable/common.rba
    runtime/stable/delta.rba
    runtime/stable/compiler.rba
    runtime/stable/loader.rbc
    runtime/stable/platform.rba
  ]

  desc "Rebuild the .load_order.txt files"
  task "load_order" do
    # Note: Steps to rebuild load_order were defined above
  end

  namespace :vm do
    task "clean" do
      sh "cd shotgun/lib; #{make "clean"}"
    end

    task "dev" do
      sh "cd shotgun/lib; #{make "DEV=1"}"
    end
  end

  task :platform => 'runtime/platform.conf'
end

# INSTALL TASKS

desc "Install rubinius as rbx"
task :install do
  sh "cd shotgun; #{make "install"}"

  mkdir_p RBAPATH, :verbose => true
  mkdir_p CODEPATH, :verbose => true

  # Install the subtend headers.
  mkdir_p EXTPATH, :verbose => true

  Rake::FileList.new('shotgun/lib/subtend/*.h').each do |file|
    install file, File.join(EXTPATH, File.basename(file)), :mode => 0644, :verbose => true
  end

  install "shotgun/config.h", File.join(EXTPATH, "config.h"), 
    :mode => 0644, :verbose => true

  File.open File.join(EXTPATH, "defines.h"), "w" do |f|
    f.puts "// This file left empty"
  end

  File.open File.join(EXTPATH, "missing.h"), "w" do |f|
    f.puts "// This file left empty"
  end

  rba_files = Rake::FileList.new('runtime/platform.conf',
                                 'runtime/**/*.rb{a,c}',
                                 'runtime/**/.load_order.txt')

  install_files rba_files, RBAPATH

  lib_files = Rake::FileList.new 'lib/**/*'

  install_files lib_files, CODEPATH

  mkdir_p File.join(CODEPATH, 'bin'), :verbose => true

  Rake::FileList.new("#{CODEPATH}/**/*.rb").sort.each do |rb_file|
    if File.exists? "#{rb_file}c"
      next if File.mtime("#{rb_file}c") > File.mtime(rb_file)
    end
    sh File.join(BINPATH, 'rbx'), 'compile', rb_file, :verbose => true
  end

  Rake::Task['gems:install'].invoke
end

desc "Uninstall rubinius and libraries. Helps with build problems."
task :uninstall do
  rm Dir[File.join(BINPATH, 'rbx*')]
  rm_r Dir[File.join(LIBPATH, '*rubinius*')]
end

task :compiledir => :stable_compiler do
  dir = ENV['DIR']
  raise "Use DIR= to set which directory" if !dir or dir.empty?
  compile_dir(dir)
end

# CLEAN TASKS

desc "Recompile all ruby system files"
task :rebuild => %w[clean build:all]

desc "Alias for clean:all"
task :clean => "clean:all"

desc "Alias for clean:distclean"
task :distclean => "clean:distclean"

namespace :clean do
  desc "Clean everything but third-party libs"
  task :all => %w[
    clean:rbc
    clean:extensions
    clean:shotgun
    clean:generated
    clean:crap
    clean:config
    gems:clean
  ]

  desc "Clean everything including third-party libs"
  task :distclean => %w[clean:all clean:external]

  desc "Remove all compile system ruby files"
  task :rbc do
    files_to_delete = []
    files_to_delete += Dir["*.rbc"] + Dir["**/*.rbc"] + Dir["**/.*.rbc"]
    files_to_delete += Dir["**/.load_order.txt"]
    files_to_delete += ["runtime/platform.conf"]
    files_to_delete -= ["runtime/stable/loader.rbc"] # never ever delete this

    files_to_delete.each do |f|
      rm_f f, :verbose => $verbose
    end
  end

  desc "Cleans all compiled extension files (lib/ext)"
  task :extensions do
    Dir["lib/ext/**/*#{$dlext}"].each do |f|
      rm_f f, :verbose => $verbose
    end
  end

  desc "Cleans up VM building site"
  task :shotgun do
    sh make('clean')
    rm_f "shotgun/dev-tramp"
  end

  desc "Cleans up generated files"
  task :generated do
    rm_f Dir["shotgun/lib/grammar.c"], :verbose => $verbose
  end

  desc "Cleans up VM and external libs"
  task :external do
    sh "cd shotgun; #{make('distclean')}"
  end

  desc "Cleans up editor files and other misc crap"
  task :crap do
    rm_f Dir["*~"] + Dir["**/*~"], :verbose => $verbose
  end

  desc "Cleans up config files (so they can be regenerated when you change PREFIX)"
  task :config do
    files = %w(shotgun/config.h shotgun/config.mk lib/rbconfig.rb)
    files.each do |file|
      rm file, :verbose => $verbose if File.exist?(file)
    end
  end
end

# MISC TASKS

desc "Build task for CruiseControl"
task :ccrb => [:build, 'spec:ci']
